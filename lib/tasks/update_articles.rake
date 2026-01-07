namespace :articles do
  desc "Update existing articles with latest prompt (options: dry_run, limit=N, post_id=N, repository=NAME)"
  task :update, [:dry_run] => :environment do |_t, args|
    # 引数からオプションを取得
    dry_run = args[:dry_run] == 'true' || args[:dry_run] == 'yes'
    post_id = args[:post_id]
    repository_name = args[:repository]
    limit = args[:limit]&.to_i

    # 更新対象の記事を取得
    posts = if post_id.present?
      # 特定の記事を指定
      Post.where(id: post_id)
    elsif repository_name.present?
      # 特定のリポジトリの記事を対象
      repository = Repository.find_by(name: repository_name)
      if repository.nil?
        puts "Repository '#{repository_name}' not found"
        exit 1
      end
      repository.posts.where(status: :published)
    else
      # 全ての公開済み記事を対象
      Post.where(status: :published)
    end

    # 件数制限を適用
    posts = posts.limit(limit) if limit.present?

    puts "=" * 80
    puts "Article Update Task"
    puts "=" * 80
    puts "Target posts: #{posts.count}"
    puts "Dry run: #{dry_run ? 'Yes' : 'No'}"
    puts "=" * 80
    puts

    if posts.empty?
      puts "No posts found to update"
      exit 0
    end

    # 各記事を処理
    success_count = 0
    skip_count = 0
    error_count = 0

    posts.find_each.with_index do |post, index|
      puts "[#{index + 1}/#{posts.count}] Processing post ##{post.id}: #{post.title}"
      puts "  Repository: #{post.repository.name}"
      puts "  Published at: #{post.published_at}"
      puts "  Source URL: #{post.source_url}"

      begin
        # source_urlからPR情報を取得する必要があるため、GitHubから再取得
        unless post.source_url.present?
          puts "  ✗ Skipped: No source URL"
          skip_count += 1
          next
        end

        # source_urlからPR番号を抽出
        pr_number = extract_pr_number_from_url(post.source_url)
        unless pr_number
          puts "  ✗ Skipped: Could not extract PR number from URL"
          skip_count += 1
          next
        end

        # GitHubからPR情報を再取得
        puts "  → Fetching PR ##{pr_number} from GitHub..."
        pr_data = fetch_pr_from_github(post.repository.name, pr_number)

        unless pr_data
          puts "  ✗ Skipped: Could not fetch PR data from GitHub"
          skip_count += 1
          next
        end

        # 最新のプロンプトで記事を再生成
        puts "  → Regenerating article with latest prompt..."
        action = Content::GenerateArticle.new(
          post.repository.name,
          pr_data,
          repository_url: post.repository.url
        )
        result = action.perform

        if result.nil?
          puts "  ✗ Skipped: Article was filtered by LLM"
          skip_count += 1
          next
        end

        # Dry runモードの場合は更新せずに結果を表示
        if dry_run
          puts "  [DRY RUN] Would update:"
          puts "    Title: #{extract_title(result[:article], post.title)}"
          puts "    Summary: #{result[:summary]&.truncate(100)}"
          puts "    Review status: #{result[:review_status]}"
          puts "    Review attempts: #{result[:review_attempts]}"
          success_count += 1
        else
          # 記事を更新
          title = extract_title(result[:article], post.title)
          post.update!(
            title: title,
            body: result[:article],
            summary: result[:summary],
            generated_by: action.model_name,
            review_status: result[:review_status],
            review_attempts: result[:review_attempts],
            review_issues: result[:review_issues],
            reviewer_model: result[:reviewer_model],
            review_details: result[:review_details]
          )
          puts "  ✓ Updated successfully"
          success_count += 1
        end
      rescue StandardError => e
        puts "  ✗ Error: #{e.message}"
        puts "    #{e.backtrace.first(3).join("\n    ")}"
        error_count += 1
      end

      puts
    end

    # 結果サマリーを表示
    puts "=" * 80
    puts "Update Summary"
    puts "=" * 80
    puts "Total processed: #{posts.count}"
    puts "Success: #{success_count}"
    puts "Skipped: #{skip_count}"
    puts "Errors: #{error_count}"
    puts "=" * 80
  end

  # source_urlからPR番号を抽出するヘルパーメソッド
  def extract_pr_number_from_url(url)
    # https://github.com/owner/repo/pull/123 形式のURLからPR番号を抽出
    match = url.match(%r{/pull/(\d+)})
    match ? match[1].to_i : nil
  end

  # GitHubからPR情報を取得するヘルパーメソッド
  def fetch_pr_from_github(repository_name, pr_number)
    require 'octokit'

    client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])

    # PR情報を取得
    pr = client.pull_request(repository_name, pr_number)

    # Diffファイルを取得
    diff_files = client.pull_request_files(repository_name, pr_number).map do |file|
      {
        filename: file.filename,
        status: file.status,
        additions: file.additions,
        deletions: file.deletions,
        patch: file.patch
      }
    end

    # PR情報をハッシュ形式で返す（DailySummaryJobと同じ形式）
    {
      number: pr.number,
      title: pr.title,
      body: pr.body,
      url: pr.html_url,
      merged_at: pr.merged_at,
      merge_commit_sha: pr.merge_commit_sha,
      diff: diff_files
    }
  rescue Octokit::Error => e
    Rails.logger.error("GitHub API error: #{e.message}")
    nil
  end

  # タイトルを抽出するヘルパーメソッド（DailySummaryJobと同じロジック）
  def extract_title(content, default_title)
    first_line = content.lines.first&.strip
    if first_line&.start_with?("#")
      first_line.gsub(/^#+\s*/, "").strip
    else
      default_title
    end
  end
end
