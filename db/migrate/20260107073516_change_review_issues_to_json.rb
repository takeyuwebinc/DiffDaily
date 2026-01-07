class ChangeReviewIssuesToJson < ActiveRecord::Migration[8.1]
  def up
    # 既存のデータをJSON文字列として保存し直す
    Post.find_each do |post|
      issues = post.review_issues
      # 配列の場合はJSON文字列に変換してから保存
      if issues.is_a?(Array)
        post.update_column(:review_issues, issues.to_json)
      elsif issues.is_a?(String)
        # すでにJSON文字列の場合は、パースして再度JSON化(正規化)
        begin
          parsed = JSON.parse(issues)
          post.update_column(:review_issues, parsed.to_json)
        rescue JSON::ParserError
          # パースエラーの場合は空配列に設定
          post.update_column(:review_issues, [].to_json)
        end
      else
        # nilやその他の場合は空配列に設定
        post.update_column(:review_issues, [].to_json)
      end
    end

    # カラムの型を変更
    change_column :posts, :review_issues, :json, default: [], null: false
  end

  def down
    change_column :posts, :review_issues, :text
  end
end
