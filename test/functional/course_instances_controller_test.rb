require 'test_helper'

class CourseInstancesControllerTest < ActionController::TestCase
  
  fixtures :users, :courses, :course_instances, :exercises
  
  # Require login
  #should_require_login :show, :new, :edit, :create, :destroy
  
  context "student" do
    setup do
      login_as :student1
    end
    
    should "be able to access course instance" do
      get :show, :id => course_instances(:active).id
      
      assert_not_nil assigns(:course_instance)
      assert_response :success
      assert_template :show
    end
    
    should "not be able to access to new" do
      get :new, :course_id => courses(:course).id
      assert_forbidden
    end
    
    should "not be able to access to edit" do
      get :edit, :id => course_instances(:active).id
      assert_forbidden
    end
    
    should "not be able to create course instance" do
      assert_difference('CourseInstance.count', 0) do 
        post :create, :course_id => courses(:course).id, :course_instance => { :name => 'Test' }
      end
      assert_forbidden
    end
    
    should "not be able to update course instance" do
      put :update, :course_id => courses(:course).id, :id => course_instances(:active).id, :course_instance => {:name => 'New name', :description => 'New description', :active => false}
      assert_forbidden
    end
    
    should "not be able to delete course instance" do
      assert_difference('CourseInstance.count', 0) do 
        delete :destroy, :id => course_instances(:active)
      end
      assert_forbidden
    end
    
#     should "not be able to access list of students" do
#       get :students, :id => course_instances(:active).id
#       assert_forbidden
#     end
  end

  context "teacher" do
    setup do
      login_as :teacher1
    end
    
    should "get instance" do
      get :show, :id => course_instances(:active).id
      
      assert_not_nil assigns(:course_instance)
      assert_response :success
      assert_template :show
    end
    
    should "be able to access new" do
      get :new, :course_id => courses(:course).id
      
      assert_not_nil assigns(:course_instance)
      assert_response :success
      assert_template :new
    end
    
    should "be able to access edit" do
      get :edit, :id => course_instances(:active).id
      
      assert_not_nil assigns(:course_instance)
      assert_response :success
      assert_template :edit
    end
    
    should "be able to create course instance" do
      assert_difference('CourseInstance.count') do 
        post :create, :course_id => courses(:course).id, :course_instance => { :name => 'Test' }
      end
    end
    
    should "be able to update course instance" do
      put :update, :course_id => courses(:course).id, :id => course_instances(:active).id, :course_instance => {:name => 'New name', :description => 'New description', :active => false}
      
      assert_redirected_to course_instance_path(assigns(:course_instance))
      assert_not_nil flash[:success], "Should set flash[:success]"
      
      assert_equal_attributes CourseInstance.find(course_instances(:active).id), {:name => 'New name', :description => 'New description', :active => false}
    end
    
    should "be able to delete course instance" do
      assert_difference('CourseInstance.count', -1) do 
        delete :destroy, :id => course_instances(:active)
      end
      
      assert_redirected_to course_path(assigns(:course))
    end
    
#     should "be able to access list of students" do
#       get :students, :id => course_instances(:active).id
#       
#       assert_not_nil assigns(:course_instance)
#       assert_response :success
#       assert_template :students
#     end
#     
#     should "be able to upload list of students" do
#       test_file = fixture_file_upload('files/students.csv','text/plain')
#       post :students, :id => course_instances(:active).id, :csv => {:file => test_file}
#       
#       old_student = User.find_by_studentnumber('00001')
#       assert_equal old_student.firstname, 'Student'
#       assert_equal old_student.lastname, '1'
#       assert_equal old_student.email, 'student1@example.com'
#       
#       new_student = User.find_by_studentnumber('93654')
#       assert_equal new_student.firstname, 'New'
#       assert_equal new_student.lastname, 'Student'
#       assert_equal new_student.email, 'newbie@example.com'
#     end
  end
  
  
end
