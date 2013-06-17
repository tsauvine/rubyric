require 'test_helper'

class CreateCourseTest < ActionController::IntegrationTest
  fixtures :all

#   test "Create course" do
#     get_via_redirect new_course_path
#     assert_equal new_session_path, path, "Should redirect to login page"
#     post_via_redirect session_path, :session => { :studentnumber => '00001', :password => 'student1' }
#     assert_equal new_course_path, path, "Should redirect to new course page"
#     
#     # Create course
#     post_via_redirect courses_path, :course => { :code => 'Test', :name => 'Course' }
#     #assert_equal new_course_course_instance_path(:course_id => ), path, "Should redirect to new instance page"
#   end
#   
#   test "Create instance" do
#     post_via_redirect session_path, :session => { :studentnumber => '10001', :password => 'teacher1' }
#     course_id = courses(:course).id
#     
#     # Create instance
#     post_via_redirect course_course_instances_path(:course_id => course_id), :course_instance => { :name => 'Spring' }
#     #assert_equal course_instance_path(course_id), path
#   end
#   
#   test "Create exercise" do
#     login_as :teacher1
#     instance_id = course_instances(:active).id
#     
#     # Create exercise
#     post_via_redirect new_course_instance_exercise_path, :course_instance_id => instance_id, :exercise => { :name => 'Exercise' }
#     
#     assert redirect?, "Should redirect to instance page"
#     #assert_equal exercise_path, path
#   end

end
