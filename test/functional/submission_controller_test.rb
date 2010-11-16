require 'test_helper'

class SubmissionControllerTest < ActionController::TestCase
  
  should_require_login :show, :new, :create
  
  context "student" do
    setup do
      login_as :student2
    end
    
    should "be able to view own submission" do
      get :show, :id => submissions(:submission).id
      
      # TODO
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
  end
  
  context "assistant" do
    setup do
      login_as :assistant1
    end
    
  end
  
  context "teacher of another course" do
    setup do
      login_as :teacher2
    end
  end
  
  context "assistant of another course" do
    setup do
      login_as :assistant1
    end
    
  end
    
end
