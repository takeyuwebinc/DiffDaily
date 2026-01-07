class CreateLinkMetadata < ActiveRecord::Migration[8.1]
  def change
    create_table :link_metadata do |t|
      t.string :url
      t.text :title
      t.text :description
      t.string :domain
      t.string :favicon
      t.string :image_url
      t.datetime :last_fetched_at

      t.timestamps
    end
    add_index :link_metadata, :url, unique: true
  end
end
