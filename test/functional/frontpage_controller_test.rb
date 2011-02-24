require 'test_helper'

class FrontpageControllerTest < ActionController::TestCase

  fixtures :users, :courses, :course_instances
  
  should 'get frontpage without logging in' do
    get :show
    
    assert_response :success
    assert_template 'info'
  end
  
  context 'as a user who logs in for the first time' do
    setup do
      login_as :newbie
    end
    
    should 'get frontpage' do
      get :show
      
      assert_response :success
      assert_template 'course_instances'
      assert_select '#enroll-info', nil, "A user who logs in for the first time should see some instructions."
    end
  end
  
  context 'as teacher' do
    setup do
      login_as :teacher1
    end
    
    should 'get frontpage' do
      get :show
      
      assert_response :success
      assert_template 'course_instances'
      assert_select '#courses-teacher', nil, "Teacher should see a list of courses"
    end
  end
  
  context 'as assistant' do
    setup do
      login_as :assistant1
    end
    
    should 'get frontpage' do
      get :show
      
      assert_response :success
      assert_template 'course_instances'
      assert_select '#courses-assistant', nil, "Assistant should see a list of courses"
    end
  end
  
  context 'as student' do
    setup do
      login_as :student1
    end
    
    should 'frontpage' do
      get :show
      
      assert_response :success
      assert_template 'course_instances'
      assert_select '#courses-student', nil, "Student should see a list of courses"
    end
  end
    
  
  def test_routes
    assert_generates "/frontpage", { :controller => "frontpage", :action => "show" }
  end
  
end
