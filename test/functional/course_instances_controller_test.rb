require 'test_helper'

class CourseInstancesControllerTest < ActionController::TestCase
  
  fixtures :users, :courses, :course_instances, :exercises
  
  # Require login
  should_require_login :show, :new, :edit, :create, :destroy
  
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
      get :new, :course => courses(:course)
      assert_forbidden
    end
    
    should "not be able to access to edit" do
      get :edit, :id => course_instances(:active).id
      assert_forbidden
    end
    
    should "not be able to create course instance" do
      post :create, :course_instance => {:course_id => courses(:course).id, :name => 'Test' }
      assert_forbidden
    end
    
    should "not be able to update course instance" do
      put :update, :id => course_instances(:active).id, :course_instance => {:name => 'New name', :description => 'New description', :active => false}
      assert_forbidden
    end
    
    should "not be able to delete course instance" do
      assert_difference('CourseInstance.count', 0) do 
        delete :destroy, :id => course_instances(:active)
      end
      assert_forbidden
    end
  end

  context "teacher" do
    setup do
      login_as :teacher1
    end
    
    should "be able to access show" do
      get :show, :id => course_instances(:active).id
      
      assert_not_nil assigns(:course_instance)
      assert_response :success
      assert_template :show
    end
    
    should "be able to access new" do
      get :new, :course => courses(:course).id
      
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
        post :create, :course_instance => {:course_id => courses(:course).id, :name => 'Test' }
      end
    end
    
    should "be able to update course instance" do
      put :update, :id => course_instances(:active).id, :course_instance => {:name => 'New name', :description => 'New description', :active => false}
      
      assert_redirected_to course_instance_path(assigns(:course_instance))
      assert_not_nil flash[:success], "Should set flash[:success]"
    end
    
    should "be able to delete course instance" do
      assert_difference('CourseInstance.count', -1) do 
        delete :destroy, :id => course_instances(:active)
      end
      
      assert_redirected_to course_path(assigns(:course))
    end
  end
  
  
end
