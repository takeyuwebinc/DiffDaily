class AddReviewFieldsToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :review_status, :string, default: "not_reviewed", null: false
    add_column :posts, :review_attempts, :integer, default: 0, null: false
    add_column :posts, :review_issues, :text

    add_index :posts, :review_status
  end
end
