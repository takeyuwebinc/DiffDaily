class AddLastFetchedAtToRepositories < ActiveRecord::Migration[8.1]
  def change
    add_column :repositories, :last_fetched_at, :datetime
  end
end
