namespace :repositories do
  desc "Import repositories from Rails organization that were pushed within the last year"
  task import_rails_repos: :environment do
    require "octokit"

    # GitHub APIクライアントの初期化
    client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])

    # 1年前の日付を計算
    one_year_ago = 1.year.ago

    puts "Fetching repositories from rails organization..."
    puts "Filtering: pushed after #{one_year_ago.strftime("%Y-%m-%d")}"

    # rails organizationのリポジトリを取得
    # auto_paginateを使用してすべてのページを自動取得
    client.auto_paginate = true
    repos = client.org_repos("rails", type: "public", sort: "pushed")

    # 1年以内にpushされたリポジトリをフィルタリング
    recent_repos = repos.select do |repo|
      repo.pushed_at && repo.pushed_at >= one_year_ago
    end

    puts "\nFound #{recent_repos.size} repositories pushed within the last year (out of #{repos.size} total)"
    puts "\nImporting repositories..."

    imported_count = 0
    skipped_count = 0
    error_count = 0

    recent_repos.each do |repo|
      full_name = repo.full_name
      url = repo.html_url
      pushed_at = repo.pushed_at

      begin
        repository = Repository.find_or_initialize_by(name: full_name)

        if repository.new_record?
          repository.url = url
          repository.save!
          puts "✓ Imported: #{full_name} (pushed: #{pushed_at.strftime("%Y-%m-%d")})"
          imported_count += 1
        else
          puts "- Skipped (already exists): #{full_name}"
          skipped_count += 1
        end
      rescue => e
        puts "✗ Error importing #{full_name}: #{e.message}"
        error_count += 1
      end
    end

    puts "\n" + "=" * 60
    puts "Import completed!"
    puts "Imported: #{imported_count}"
    puts "Skipped: #{skipped_count}"
    puts "Errors: #{error_count}"
    puts "Total repositories in database: #{Repository.count}"
    puts "=" * 60
  end
end
