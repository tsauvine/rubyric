class ReviewNotes < ActiveRecord::Migration
  def self.up
    add_column :reviews, :notes_to_teacher, :text
    add_column :reviews, :notes_to_grader, :text
  end

  def self.down
    remove_column :exercises, :notes_to_teacher
    remove_column :exercises, :notes_to_grader
  end
end
