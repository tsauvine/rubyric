ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

require 'authlogic/test_case'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  #fixtures :all
  
  setup :activate_authlogic

  # Add more helper methods to be used by all tests here...
  def login_as(user)
    Session.create(users(user))
  end

#   def self.should_require_login(*actions)
#     actions.each do |action|
#       should "Require login for '#{action}' action" do
#         get action
#         assert_redirected_to new_session_path
#       end
#     end
#   end

  def assert_forbidden
    assert_response :forbidden
    assert_template 'shared/forbidden'
  end
 
  def current_user
    unless defined?(@current_session)
      @current_session = Session.find
    end
    
    unless defined?(@current_user)
      @current_user = @current_session.user if @current_session
    end
    
    @current_user
  end
  
  # object: ActiveRecord object
  # expected_attributes: hash of expected attributes and values
  def assert_equal_attributes(object, expected_attributes)
    expected_attributes.each do |index, value|
      assert_equal value, object[index], "#{index}"
    end
  end
end
