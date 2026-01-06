namespace :posts do
  desc "Fix posts with JSON in body field"
  task fix_json_body: :environment do
    posts = Post.where("body LIKE ?", "```json%")

    puts "Found #{posts.count} posts with JSON in body"

    posts.each do |post|
      puts "Fixing post ##{post.id}: #{post.title}"

      # bodyからJSONを抽出してパース
      json_text = post.body.strip

      # ```json で始まり ``` で終わるパターンを探す
      if json_text.start_with?("```json") && json_text.end_with?("```")
        json_text = json_text.sub(/\A```json\s*/, "").sub(/\s*```\z/, "")
      end

      begin
        parsed = JSON.parse(json_text)

        # articleとsummaryを取り出す
        article = parsed["article"]
        summary = parsed["summary"]

        # タイトルも再抽出
        first_line = article.lines.first&.strip
        if first_line&.start_with?("#")
          title = first_line.gsub(/^#+\s*/, "").strip
        else
          title = post.title
        end

        # 更新
        post.update!(
          title: title,
          body: article,
          summary: summary
        )

        puts "  ✓ Fixed: #{title}"
      rescue JSON::ParserError => e
        puts "  ✗ Failed to parse JSON: #{e.message}"
      rescue StandardError => e
        puts "  ✗ Error: #{e.message}"
      end
    end

    puts "Done!"
  end

  desc "Regenerate summaries for posts without summary"
  task regenerate_summaries: :environment do
    posts = Post.where(summary: nil).where(status: :published)

    puts "Found #{posts.count} posts without summary"

    posts.each do |post|
      puts "Regenerating summary for post ##{post.id}: #{post.title}"

      # 本文の最初の段落を取得（簡易版）
      # より良い要約が必要な場合は、LLMで再生成する必要があります
      body_without_title = post.body.sub(/\A#\s+.*?\n+/, '')
      first_paragraph = body_without_title.split("\n\n").first&.strip

      if first_paragraph.present?
        # Markdownマークアップを削除
        summary = first_paragraph
          .gsub(/\*\*(.+?)\*\*/, '\1')  # Bold
          .gsub(/\*(.+?)\*/, '\1')       # Italic
          .gsub(/`(.+?)`/, '\1')         # Code
          .gsub(/\[(.+?)\]\(.+?\)/, '\1') # Links
          .strip

        # 最大200文字に制限
        summary = summary.truncate(200, separator: "。")

        post.update!(summary: summary)
        puts "  ✓ Generated summary: #{summary[0..50]}..."
      else
        puts "  ✗ Could not extract summary"
      end
    end

    puts "Done!"
  end
end
