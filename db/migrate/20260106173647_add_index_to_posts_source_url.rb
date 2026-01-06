class AddIndexToPostsSourceUrl < ActiveRecord::Migration[8.1]
  def change
    add_index :posts, :source_url
    add_index :posts, [:repository_id, :source_url], unique: true
  end
end
