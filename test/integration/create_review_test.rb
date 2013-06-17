require 'test_helper'

class CreateReviewTest < ActionDispatch::IntegrationTest
  #fixtures :reviews, :users, :submissions, :exercises
  fixtures :all
  
  setup do
    Capybara.current_driver = Capybara.javascript_driver = :webkit
  end

  test 'Create review' do
    get edit_review_path(reviews(:review))
    
    
    #click_link('id-of-link')
    
    
  end
end 
