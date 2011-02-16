require File.dirname(__FILE__) + '/../test_helper'

class UserTest < ActiveSupport::TestCase
  fixtures :users, :courses

  should "create user with only studentnumber" do
    user = User.new
    user.studentnumber = '973582'
    
    assert_difference('User.count', 1) do
      user.save
      assert !user.new_record?, "#{user.errors.full_messages.to_sentence}"
    end
  end
  
  should "not create user if studentnumber exists" do
    user = User.new
    user.studentnumber = '00001'
    
    assert_difference('User.count', 0) do
      user.save
    end
  end
  
  should "not create user if login exists" do
    user = User.new
    user.login = '00001'
    user.studentnumber = '892648'
    
    assert_difference('User.count', 0) do
      user.save
    end
  end
  
  should "not be admin" do
    user = User.find(users(:student1).id)
    assert !user.admin?, "Student should not be admin"
  end
  
  should "be admin" do
    user = User.find(users(:admin).id)
    assert user.admin?, "Admin should be admin"
  end
  
  should "not be teacher" do
    user = User.find(users(:student1).id)
    assert !user.teacher?, "Student should not be teacher"
  end
  
  should "be teacher" do
    user = User.find(users(:teacher1).id)
    assert user.teacher?, "Teacher should be teacher"
  end
  
end
