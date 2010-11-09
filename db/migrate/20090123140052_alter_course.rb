class AlterCourse < ActiveRecord::Migration
  def self.up
    add_column :courses, :email, :string
    add_column :exercises, :grading_mode, :string, :default => 'average'

    execute "UPDATE exercises SET grading_mode='average'"

  end

  def self.down
    remove_column :courses, :email
    remove_column :exercises, :grading_mode
  end
end
