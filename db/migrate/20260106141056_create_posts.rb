class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :repository, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body, null: false
      t.string :source_url
      t.string :generated_by
      t.datetime :published_at
      t.string :status, null: false, default: "draft"

      t.timestamps
    end

    add_index :posts, :status
    add_index :posts, :published_at
  end
end
