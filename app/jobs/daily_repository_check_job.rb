class DailyRepositoryCheckJob < ApplicationJob
  queue_as :default

  # 取得間隔（デフォルト24時間）
  FETCH_INTERVAL = 24.hours

  # 取得間隔を経過したリポジトリのPRを取得する
  # 30分ごとに実行され、取得対象のリポジトリのみを処理することで負荷を分散
  def perform
    Rails.logger.info "Starting interval-based repository check"

    repositories = Repository.all

    if repositories.empty?
      Rails.logger.info "No repositories found"
      return
    end

    due_repositories = repositories.select { |repo| fetch_due?(repo) }

    if due_repositories.empty?
      Rails.logger.info "No repositories due for fetching (checked #{repositories.count} repositories)"
      return
    end

    Rails.logger.info "Found #{due_repositories.count} repositories due for fetching (out of #{repositories.count} total)"

    due_repositories.each do |repository|
      begin
        Rails.logger.info "Fetching repository: #{repository.name} (last fetched: #{repository.last_fetched_at || 'never'})"

        DailySummaryJob.perform_now(repository.id)

        Rails.logger.info "Completed fetch for #{repository.name}"
      rescue StandardError => e
        Rails.logger.error "Failed to fetch repository #{repository.name}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    Rails.logger.info "Completed interval-based repository check"
  end

  private

  # リポジトリが取得対象かどうかを判定
  # - last_fetched_atがNULLの場合: 取得対象
  # - last_fetched_at + 取得間隔 <= 現在時刻の場合: 取得対象
  def fetch_due?(repository)
    return true if repository.last_fetched_at.nil?

    repository.last_fetched_at + FETCH_INTERVAL <= Time.current
  end
end
