class AddReviewerDetailsToPost < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :reviewer_model, :string
    add_column :posts, :review_details, :json
  end
end
