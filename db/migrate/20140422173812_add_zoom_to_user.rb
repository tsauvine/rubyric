class AddZoomToUser < ActiveRecord::Migration
  def change
    add_column :users, :zoom_preference, :integer
    add_column :users, :submission_sort_preference, :string
  end
end
