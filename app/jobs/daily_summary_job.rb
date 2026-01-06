class DailySummaryJob < ApplicationJob
  queue_as :default

  # リポジトリIDまたはリポジトリ名を指定して実行
  def perform(repository_id_or_name)
    repository = find_repository(repository_id_or_name)
    return unless repository

    Rails.logger.info "Starting daily summary for #{repository.name}"

    # GitHubから過去24時間の変更を取得
    recent_changes = Github::FetchRecentChanges.perform(repository.name, hours_ago: 24)

    if recent_changes.empty?
      Rails.logger.info "No recent changes found for #{repository.name}"
      return
    end

    Rails.logger.info "Found #{recent_changes.size} pull requests for #{repository.name}"

    # 各Pull Requestについて記事を生成
    recent_changes.each do |pr_data|
      process_pull_request(repository, pr_data)
    end

    Rails.logger.info "Completed daily summary for #{repository.name}"
  end

  private

  def find_repository(identifier)
    if identifier.is_a?(Integer) || identifier.to_s.match?(/^\d+$/)
      Repository.find_by(id: identifier)
    else
      Repository.find_by(name: identifier)
    end
  end

  def process_pull_request(repository, pr_data)
    Rails.logger.info "Processing PR ##{pr_data[:number]}: #{pr_data[:title]}"

    # 既に記事が作成されているかチェック
    existing_post = repository.posts.find_by(source_url: pr_data[:url])
    if existing_post
      Rails.logger.info "Skipped PR ##{pr_data[:number]} (already exists as post ##{existing_post.id})"
      return
    end

    # LLMで記事を生成（Claude Sonnet 4.5使用）
    action = Content::GenerateArticle.new(repository.name, pr_data)
    result = action.perform

    if result.nil?
      # SKIPの場合
      Rails.logger.info "Skipped PR ##{pr_data[:number]} (filtered by LLM)"
      create_skipped_post(repository, pr_data)
      return
    end

    # resultはハッシュ形式: { article: "...", summary: "...", review_status: "...", review_attempts: N, review_issues: [...] }
    article_content = result[:article]
    summary = result[:summary]
    review_status = result[:review_status]
    review_attempts = result[:review_attempts]
    review_issues = result[:review_issues]

    # タイトルを記事の最初の行から抽出（# で始まる行）
    title = extract_title(article_content, pr_data[:title])

    # 記事を保存
    post = repository.posts.create!(
      title: title,
      body: article_content,
      summary: summary,
      source_url: pr_data[:url],
      generated_by: action.model_name,
      published_at: Time.current,
      status: :published,
      review_status: review_status,
      review_attempts: review_attempts,
      review_issues: review_issues
    )

    Rails.logger.info "Created post ##{post.id}: #{post.title}"
  rescue StandardError => e
    Rails.logger.error "Failed to process PR ##{pr_data[:number]}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def create_skipped_post(repository, pr_data)
    repository.posts.create!(
      title: "[SKIPPED] #{pr_data[:title]}",
      body: "This PR was skipped by content filtering.",
      source_url: pr_data[:url],
      generated_by: "Filter",
      status: :skipped
    )
  end

  def extract_title(content, default_title)
    # Markdownの最初の見出し（# で始まる行）を抽出
    first_line = content.lines.first&.strip
    if first_line&.start_with?("#")
      first_line.gsub(/^#+\s*/, "").strip
    else
      default_title
    end
  end
end
