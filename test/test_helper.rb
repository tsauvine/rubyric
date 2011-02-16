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
#   def login_as(user)
#     #@request.session[:user_id] = users(user).id
#     Session.create(users(user))
#   end
#   
#   def self.should_require_login(*actions)
#     actions.each do |action|
#       should "Require login for '#{action}' action" do
#         get(action)
#         assert_redirected_to(new_session_url)
#       end
#     end
#   end
#   
#   def assert_forbidden
#     assert_response :forbidden
#     assert_template 'shared/forbidden'
#   end

#   def current_session
#     return @current_session if defined?(@current_session)
#     @current_session = Session.find
#   end
  
  def current_user
    #return @current_user if defined?(@current_user)
    #@current_user = current_session && current_session.record
    #session = Session.find
    #return session && session.record
    
    session = Session.find
    session && session.user
  end
end
