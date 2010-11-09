class AlterCourseInstance < ActiveRecord::Migration
  def self.up
    remove_column :exercises, :email_immediately
    add_column :exercises, :grader_can_email, :boolean, :default => false
    add_column :exercises, :unregistered_can_submit, :boolean
    add_column :submissions, :filename, :string
    add_column :reviews, :calculated_grade, :int
    add_column :reviews, :final_grade, :int
    add_column :course_instances, :inactive, :boolean
    add_column :course_instances, :description, :text
    add_column :sections, :weight, :float, :default => 1.0
    add_column :items, :instructions, :string
  end

  def self.down
    add_column :exercises, :email_immediately, :boolean
    add_column :sections, :weight
    remove_column :exercises, :grader_can_mail
    remove_column :exercises, :unregistered_can_submit
    remove_column :submissions, :filename
    remove_column :reviews, :calculated_grade
    remove_column :reviews, :final_grade
    remove_column :course_instances, :inactive
    remove_column :course_instances, :description
    remove_column :sections, :weight
    remove_column :items, :instructions
  end
end
