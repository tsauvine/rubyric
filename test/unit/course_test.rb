require 'test_helper'

class CourseTest < ActiveSupport::TestCase

  fixtures :courses, :users
  
  
  should "have teacher1 as teacher" do
    assert courses(:course).has_teacher(users(:teacher1))
  end
  
  should "not have teacher2 as teacher" do
    assert !courses(:course).has_teacher(users(:teacher2))
  end
  
  should "not have student1 as teacher" do
    assert !courses(:course).has_teacher(users(:student1))
  end
  
  should "return false for has_teacher(nil)" do
    assert !courses(:course).has_teacher(nil)
  end
  
  
  should "use the specified email address" do
    assert_equal courses(:course_with_email).email, 'course@example.com'
  end
  
  should "use teacher's email address" do
    assert_equal courses(:course_without_email).email, 'teacher1@example.com'
  end
  
  should "return empty email address" do
    assert_equal courses(:course_without_teacher).email, ''
  end
  
  should "remove teacher" do
    courses(:course).remove_teacher(users(:teacher1))
    assert !courses(:course).has_teacher(users(:teacher1))
  end
  
  should "remove teacher by id" do
    courses(:course).remove_teacher(users(:teacher1).id)
    assert !courses(:course).has_teacher(users(:teacher1))
  end
  
  should "not remove user who is not a teacher on the course in the first place" do
    courses(:course).remove_teacher(users(:teacher2))
  end
  
  should "remove teachers" do
    courses(:course).remove_teachers([users(:teacher1)])
    assert !courses(:course).has_teacher(users(:teacher1))
  end
  
  should "remove teachers by id" do
    courses(:course).remove_teachers([users(:teacher1).id])
    assert !courses(:course).has_teacher(users(:teacher1))
  end
  
end
