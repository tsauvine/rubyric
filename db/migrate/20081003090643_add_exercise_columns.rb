class AddExerciseColumns < ActiveRecord::Migration
  def self.up
    add_column :exercises, :anonymous_graders, :boolean, :default => false
    add_column :exercises, :anonymous_submissions, :boolean, :default => false
    add_column :exercises, :email_immediately, :boolean, :default => false
    add_column :exercises, :submit_post_message, :text
  end

  def self.down
    remove_column :exercises, :anonymous_graders
    remove_column :exercises, :anonymous_submissions
    remove_column :exercises, :email_immediately
    remove_column :exercises, :submit_post_message
  end
end
