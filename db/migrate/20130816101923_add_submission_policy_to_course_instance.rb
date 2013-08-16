class AddSubmissionPolicyToCourseInstance < ActiveRecord::Migration
  def change
    add_column :course_instances, :submission_policy, :string
    CourseInstance.update_all(:submission_policy => 'authenticated')
  end
end
