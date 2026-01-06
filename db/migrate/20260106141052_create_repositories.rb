class CreateRepositories < ActiveRecord::Migration[8.1]
  def change
    create_table :repositories do |t|
      t.string :name, null: false
      t.string :url, null: false

      t.timestamps
    end

    add_index :repositories, :name, unique: true
  end
end
