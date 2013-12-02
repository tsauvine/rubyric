class AddBookModeToSubmission < ActiveRecord::Migration
  def change
    add_column :submissions, :book_mode, :boolean
    add_column :submissions, :page_count, :integer
    add_column :submissions, :page_width, :float
    add_column :submissions, :page_height, :float
  end
end
