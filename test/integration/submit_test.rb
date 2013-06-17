require 'test_helper'

class SubmitTest < ActionController::IntegrationTest
  fixtures :all

#   test "Submit" do
#     exercise_id = exercises(:solo_exercise).id
#     
#     # Login as student1
#     get_via_redirect submit_url(exercise_id)
#     assert_equal new_session_path, path
#     post_via_redirect session_path, :studentnumber => '00001', :password => 'student1'
#     
#     # Submit
#     assert_equal submit_path(exercise_id), path
#     
#     
#     
#   end
#   
#   
#   test "Submit group exercise" do
#     exercise_id = exercises(:group_exercise).id
#     
#     # Login as student1
#     get_via_redirect submit_url(exercise_id)
#     assert_equal new_session_path, path
#     post_via_redirect session_path, :studentnumber => '00001', :password => 'student1'
#     
#     # Create group
#     assert_equal new_group_path(:exercise => exercise_id), path
#     post_via_redirect groups_path, {:group => {:exercise_id => exercise_id}, :exercise => exercise_id, 'studentnumber[0]' => '00001', 'studentnumber[1]' => '00002', 'email[0]' => 'student1@example.com', 'email[1]' => 'student2@example.com'}
#     
#     # Submit
#     assert_equal submit_path(exercise_id), path
#     
#     # Logout
#     
#     # Login as student2
#     
#     # Submit
#     
#     
#   end
  
  
  
  
end
