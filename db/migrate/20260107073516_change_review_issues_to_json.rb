class ChangeReviewIssuesToJson < ActiveRecord::Migration[8.1]
  def up
    # 既存のデータを一時的に保存
    Post.find_each do |post|
      if post.review_issues.is_a?(String)
        post.update_column(:review_issues, JSON.parse(post.review_issues))
      end
    rescue JSON::ParserError
      # パースエラーの場合は空配列に設定
      post.update_column(:review_issues, [])
    end

    # カラムの型を変更
    change_column :posts, :review_issues, :json
  end

  def down
    change_column :posts, :review_issues, :text
  end
end
