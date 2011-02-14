require 'test_helper'

class CourseTest < ActiveSupport::TestCase

  fixtures :courses, :users
  
  
  should "have teacher1 as teacher" do
    assert courses(:course).teachers.include?(users(:teacher1))
  end
  
  should "not have teacher2 as teacher" do
    assert !courses(:course).teachers.include?(users(:teacher2))
  end
  
  should "not have student1 as teacher" do
    assert !courses(:course).teachers.include?(users(:student1))
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
  
  
  # TODO: remove_teacher
  # TODO: remove_teachers
  
end
