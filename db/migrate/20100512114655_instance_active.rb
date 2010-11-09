class InstanceActive < ActiveRecord::Migration
  def self.up
    add_column :course_instances, :active, :boolean, :default => true
    remove_column :course_instances, :inactive
    
    CourseInstance.update_all('active = true')
  end

  def self.down
    add_column :course_instances, :inactive, :boolean, :default => false
    remove_column :course_instances, :active
  end
end
