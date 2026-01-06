class DailyRepositoryCheckJob < ApplicationJob
  queue_as :default

  # 全リポジトリの過去24時間の変更をチェックして記事を生成
  def perform
    Rails.logger.info "Starting daily repository check for all repositories"

    repositories = Repository.all

    if repositories.empty?
      Rails.logger.info "No repositories found"
      return
    end

    Rails.logger.info "Found #{repositories.count} repositories to check"

    repositories.each do |repository|
      begin
        Rails.logger.info "Checking repository: #{repository.name}"

        # 各リポジトリに対してDailySummaryJobを実行
        DailySummaryJob.perform_now(repository.id)

        Rails.logger.info "Completed check for #{repository.name}"
      rescue StandardError => e
        Rails.logger.error "Failed to check repository #{repository.name}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    Rails.logger.info "Completed daily repository check for all repositories"
  end
end
