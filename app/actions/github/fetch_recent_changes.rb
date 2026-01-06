module Github
  class FetchRecentChanges < ApplicationAction
    # 過去24時間のマージされたPull Requestsとその差分を取得する
    # ノイズをフィルタリングして返す

    def initialize(repository_name, hours_ago: 24, access_token: nil)
      @repository_name = repository_name
      @hours_ago = hours_ago
      @client = Octokit::Client.new(access_token: access_token || ENV["GITHUB_ACCESS_TOKEN"])
    end

    def perform
      since = @hours_ago.hours.ago
      pull_requests = fetch_merged_pull_requests(since)
      filtered_prs = filter_noise(pull_requests)

      filtered_prs.map do |pr|
        {
          number: pr[:number],
          title: pr[:title],
          body: pr[:body],
          url: pr[:html_url],
          merged_at: pr[:merged_at],
          diff: fetch_diff(pr[:number])
        }
      end
    end

    private

    def fetch_merged_pull_requests(since)
      pulls = @client.pull_requests(
        @repository_name,
        state: "closed",
        sort: "updated",
        direction: "desc"
      )

      pulls.select do |pr|
        pr[:merged_at] && pr[:merged_at] >= since
      end
    end

    def fetch_diff(pr_number)
      files = @client.pull_request_files(@repository_name, pr_number)

      files.map do |file|
        {
          filename: file[:filename],
          status: file[:status],
          additions: file[:additions],
          deletions: file[:deletions],
          patch: file[:patch]
        }
      end
    end

    def filter_noise(pull_requests)
      pull_requests.reject do |pr|
        title = pr[:title].downcase
        body = pr[:body]&.downcase || ""

        # Dependabot
        next true if pr[:user][:login] == "dependabot[bot]"

        # タイトルでのフィルタリング
        next true if title.match?(/\b(doc|readme|typo|ci|workflow|github actions)\b/i)

        # ラベルでのフィルタリング
        labels = pr[:labels]&.map { |l| l[:name].downcase } || []
        next true if (labels & ["documentation", "dependencies", "ci"]).any?

        false
      end
    end
  end
end
