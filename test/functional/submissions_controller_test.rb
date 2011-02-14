require 'test_helper'

class SubmissionsControllerTest < ActionController::TestCase
  fixtures :users, :groups, :submissions, :exercises
  
  #should_require_login :show, :new, :create
  
  context "student accessing own submission" do
    setup do
      login_as :student1
    end
    
    should "be able to view own submission" do
      get :show, :id => submissions(:submission).id
      assert_response(:success)
    end
    
    
    # Submit:
    # include ActionDispatch::TestProcess # For Rails 3
    # file = fixture_file_upload('files/test_submission.txt','text/plain')
    # post :create, :file => file
  end
  
  context "student accessing somebody else's submission" do
    setup do
      login_as :student2
    end
    
    should "not be able to view somebody else's submission" do
      get :show, :id => submissions(:submission).id
      assert_forbidden
    end
    
  end
  
  context "teacher" do
    setup do
      login_as :teacher1
    end
    
    should "be able to view submission" do
      get :show, :id => submissions(:submission).id
      assert_response(:success)
    end
  end
  
  context "assistant" do
    setup do
      login_as :assistant1
    end
    
    should "be able to view submission" do
      get :show, :id => submissions(:submission).id
      assert_response(:success)
    end
  end
  
  context "teacher of another course" do
    setup do
      login_as :teacher2
    end
    
    should "not be able to view submission" do
      get :show, :id => submissions(:submission).id
      assert_forbidden
    end
  end
  
  context "assistant of another course" do
    setup do
      login_as :assistant3
    end
    
    should "not be able to view submission" do
      get :show, :id => submissions(:submission).id
      assert_forbidden
    end
  end
  
end
