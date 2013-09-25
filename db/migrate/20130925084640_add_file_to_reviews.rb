class AddFileToReviews < ActiveRecord::Migration
  def change
    add_column :reviews, :filename, :string
    add_column :reviews, :extension, :string
  end
end
