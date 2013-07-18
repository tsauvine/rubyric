class GroupToInstance < ActiveRecord::Migration
  def self.up
    add_column :groups, :course_instance_id, :integer
    
    add_column :groups_users, :studentnumber, :string
    add_column :groups_users, :email, :string
    
    # Copy course instance id
    execute 'UPDATE groups SET course_instance_id=exercises.course_instance_id FROM exercises WHERE groups.exercise_id = exercises.id'
  end

  def self.down
    remove_column :groups, :course_instance_id
    remove_column :groups, :studentnumber
    remove_column :groups, :email
  end
end
