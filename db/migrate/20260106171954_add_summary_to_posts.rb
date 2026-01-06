class AddSummaryToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :summary, :text
  end
end
