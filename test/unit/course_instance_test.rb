require 'test_helper'

class CourseInstanceTest < ActiveSupport::TestCase
  
  fixtures :users, :courses, :course_instances
  
  #should_not_allow_mass_assignment_of :course_id

  
  should "have assistant1 as assistant" do
    assert course_instances(:active).assistants.include?(users(:assistant1))
  end
  
  should "not have assistant2 as assistant" do
    assert !course_instances(:active).assistants.include?(users(:assistant2))
  end
  
  should "not have student1 as assistant" do
    assert !course_instances(:active).assistants.include?(users(:student1))
  end
  
  # TODO: add_users, remove_students, etc...
  
end
