require 'test_helper'

class CoursesControllerTest < ActionController::TestCase

  fixtures :users, :courses
  
  context "not logged in" do
    should "not get index" do
      get :index
      assert_redirected_to new_session_path
    end
    
    should "not get course" do
      get :show, :id => courses(:course).id
      assert_redirected_to new_session_path
    end
    
    should "not get new" do
      get :new
      assert_redirected_to new_session_path
    end
    
    should "not get edit" do
      get :edit, :id => courses(:course).id
      assert_redirected_to new_session_path
    end
    
    should "not be able to create course instance" do
      assert_difference('Course.count', 0) do 
        post :create, :course => {:code => '93765', :name => 'New course' }
      end
      
      assert_redirected_to new_session_path
    end
    
    should "not be able to update course instance" do
      put :update, :id => courses(:course).id, :course => { :code => '93777', :name => 'New name' }
      assert_redirected_to new_session_path
    end
    
    should "not be able to delete course instance" do
      assert_difference('Course.count', 0) do 
        delete :destroy, :id => courses(:course).id
      end
      assert_redirected_to new_session_path
    end
    
#     should "not get teachers" do
#       get :teachers, :id => courses(:course).id
#       assert_redirected_to new_session_path
#     end
    
    # TODO: add/remove teachers
  end
  
  context "student" do
    setup do
      login_as :student1
    end
    
    should "get index" do
      get :index
      
      assert_not_nil assigns(:courses)
      assert_response :success
      assert_template :index
    end
    
    should "get course" do
      get :show, :id => courses(:course).id
      
      assert_not_nil assigns(:course)
      assert_response :success
      assert_template :show
    end
    
    should "get new" do
      get :new
      
      assert_response :success
      assert_template :new
    end
    
    should "not get edit" do
      get :edit, :id => courses(:course).id
      assert_forbidden
    end
    
    should "be able to create course instance" do
      assert_difference('Course.count', 1) do 
        post :create, :course => {:code => '93765', :name => 'New course' }
      end
      
      assert_redirected_to new_course_instance_path(:course => assigns(:course).id)
    end
    
    should "not be able to update course instance" do
      put :update, :id => courses(:course).id, :course => { :code => '93777', :name => 'New name' }
      assert_forbidden
    end
    
    should "not be able to delete course instance" do
      assert_difference('Course.count', 0) do 
        delete :destroy, :id => courses(:course).id
      end
      assert_forbidden
    end
  end
 
  context 'teacher' do
    setup do
      login_as :teacher1
    end
    
    should "get index" do
      get :index
      
      assert_not_nil assigns(:courses)
      assert_response :success
      assert_template :index
    end
    
    should "get course" do
      get :show, :id => courses(:course).id
      
      assert_not_nil assigns(:course)
      assert_response :success
      assert_template :show
    end
    
    should "get new" do
      get :new
      
      assert_response :success
      assert_template :new
    end
    
    should "get edit" do
      get :edit, :id => courses(:course).id
      
      assert_response :success
      assert_template :edit
    end
    
    should "be able to create course instance" do
      assert_difference('Course.count') do 
        post :create, :course => {:code => '93765', :name => 'New course' }
      end
      
      assert_redirected_to new_course_instance_path(:course => assigns(:course).id)
    end
    
    should "be able to update course instance" do
      put :update, :id => courses(:course).id, :course => { :code => '93777', :name => 'New name' }
      
      assert_redirected_to course_path(assigns(:course))
    end
    
    should "be able to delete course instance" do
      assert_difference('Course.count', -1) do 
        delete :destroy, :id => courses(:course).id
      end
      
      assert_redirected_to courses_path
    end
    
#     should "get teachers" do
#       get :teachers, :id => courses(:course).id
#       
#       assert_response :success
#       assert_template :teachers
#     end
  end
  
end
