require 'test_helper'

class SessionsControllerTest < ActionController::TestCase

  fixtures :users

  should 'not accept non-existing user' do
    post :create, :session => {:studentnumber => 'nobody', :password => 'nobody'}
    assert_nil current_user
    assert_response :success
  end
  
  should 'not accept invalid password' do
    post :create, :session => {:studentnumber => '00001', :password => 'invalid'}
    assert_nil current_user
    assert_response :success
  end
  
  should 'not accept empty password' do
    post :create, :session => {:studentnumber => '00001', :password => ''}
    assert_nil current_user
    assert_response :success
  end
  
  should 'not accept missing password' do
    post :create, :session => {:studentnumber => '00001'}
    assert_nil current_user
    assert_response :success
  end
  
  should 'not accept empty username' do
    post :create, :session => {:studentnumber => '', :password => 'student1'}
    assert_nil current_user
    assert_response :success
  end
  
  should 'not accept missing username' do
    post :create, :session => {:password => 'student1'}
    assert_nil current_user
    assert_response :success
  end
  
  should 'not accept empty username and password' do
    post :create, :session => {:studentnumber => '', :password => ''}
    assert_nil current_user
    assert_response :success
  end
  
  should 'not accept missing username and password' do
    post :create
    assert_nil current_user
    assert_response :success
  end
  
  should 'accept valid password' do
    post :create, :session => {:studentnumber => '00001', :password => 'student1'}
    assert user_session = Session.find
    assert_equal users(:student1), user_session.user
    assert_response :redirect
  end
  
  
  # User has been created with studentnumber only and then logs in with shibboleth
  # Attributes should be updated
  should 'update attributes after first login with shibboleth' do
    @request.env['HTTP_EPPN'] = 'newuser@example.com'
    @request.env['HTTP_SCHACPERSONALUNIQUECODE'] = '00022'
    @request.env['HTTP_DISPLAYNAME'] = 'Student'
    @request.env['HTTP_SN'] = '22'
    @request.env['HTTP_MAIL'] = 'student22@example.com'
    @request.env['HTTP_SCHACHOMEORGANIZATION'] = 'example.com'
    @request.env['HTTP_LOGOUTURL'] = 'http://logout.example.com/'
    
    get :shibboleth
    assert user_session = Session.find
    assert_equal users(:ghost), user_session.user
    assert_response :redirect
    
    # Attributes should be updated
    user = User.find(users(:ghost).id)
    assert_equal 'newuser@example.com', user.login
    assert_equal '00022', user.studentnumber
    assert_equal 'Student', user.firstname
    assert_equal '22', user.lastname
    assert_equal 'student22@example.com', user.email
    assert_equal 'example.com', user.organization
  end
  
  # User logs in for the first time with shibboleth
  # User should be created
  should 'create user after first login with shibboleth' do
    @request.env['HTTP_EPPN'] = 'newbie@example.com'
    @request.env['HTTP_SCHACPERSONALUNIQUECODE'] = '00023'
    @request.env['HTTP_DISPLAYNAME'] = 'Student'
    @request.env['HTTP_SN'] = '23'
    @request.env['HTTP_MAIL'] = 'student23@example.com'
    @request.env['HTTP_SCHACHOMEORGANIZATION'] = 'example.com'
    @request.env['HTTP_LOGOUTURL'] = 'http://logout.example.com/'
    
    assert_difference('User.count', 1) do 
      get :shibboleth
      assert user_session = Session.find, "Session should exist but it doesn't"
      assert_response :redirect
    end
  end
  
  # Existing user logs in with shibboleth
  # Existing attributes should not be overwritten
  should 'let in with shibboleth' do
    @request.env['HTTP_EPPN'] = 'shibuser@example.com'
    @request.env['HTTP_SCHACPERSONALUNIQUECODE'] = '00029'
    @request.env['HTTP_DISPLAYNAME'] = 'New firstname'
    @request.env['HTTP_SN'] = 'New lastname'
    @request.env['HTTP_MAIL'] = 'new-mail@example.com'
    @request.env['HTTP_SCHACHOMEORGANIZATION'] = 'example.com'
    @request.env['HTTP_LOGOUTURL'] = 'http://logout.example.com/'
    
    get :shibboleth
    assert user_session = Session.find, "Session should exist but doesn't"
    assert_equal users(:shibuser), user_session.user
    assert_response :redirect
    
    # Existing attributes should not be overwritten
    user = User.find(users(:shibuser).id)
    assert_equal 'shibuser@example.com', user.login
    assert_equal '00021', user.studentnumber
    assert_equal 'Student', user.firstname
    assert_equal '21', user.lastname
    assert_equal 'student21@example.com', user.email
    assert_equal 'example.com', user.organization
  end

  # User with a reserved studentnumber logs in from another organization
  should 'not allow to login if studentnumber is reserved' do
    @request.env['HTTP_EPPN'] = 'somebody@otheruniversity.com'
    @request.env['HTTP_SCHACPERSONALUNIQUECODE'] = '00021'
    @request.env['HTTP_DISPLAYNAME'] = 'Somebody'
    @request.env['HTTP_SN'] = 'Strange'
    @request.env['HTTP_MAIL'] = 'somebody@example.com'
    @request.env['HTTP_SCHACHOMEORGANIZATION'] = 'otheruniversity.com'
    @request.env['HTTP_LOGOUTURL'] = 'http://logout.example.com/'
    
    get :shibboleth
    assert_nil current_user
    assert_response :success
  end
  
  # TODO: logout shibboleth
  
  # TODO: logout traditional
  
  
  # TODO: integration
  # Unauthenticated user tries to access a restricted page
  # Should redirect to login



#   def test_should_logout
#     login_as :quentin
#     get :destroy
#     assert_nil session[:user_id]
#     assert_response :redirect
#   end


end
