class AddLtiToCourseInstance < ActiveRecord::Migration
  def change
    add_column :course_instances, :lti_consumer, :string
    add_column :course_instances, :lti_context_id, :string
    add_column :course_instances, :lti_resource_link_id, :string
    add_index :course_instances, [:lti_consumer, :lti_context_id]
  end
end
