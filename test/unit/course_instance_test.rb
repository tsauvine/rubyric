require 'test_helper'

class CourseInstanceTest < ActiveSupport::TestCase
  
  fixtures :users, :courses, :course_instances
  
  #should_not_allow_mass_assignment_of :course_id

  
  should "have assistant1 as assistant" do
    assert course_instances(:active).has_assistant(users(:assistant1))
  end
  
  should "not have assistant2 as assistant" do
    assert !course_instances(:active).has_assistant(users(:assistant2))
  end
  
  should "not have student1 as assistant" do
    assert !course_instances(:active).has_assistant(users(:student1))
  end
  
  should "add students from csv" do
    instance = course_instances(:active)
    
    # Format: studentnumber, firstname, lastname, email, password
    # existing student, new student, existing student with only studentnumber, new student with only studentnumber
    csv = "00001, New, Name, new@example.com, newpass\n 82735, Newbie, Student, newstudent@example.com, qwerty\n 00002 \n 28462"
    instance.add_students_csv(csv)
    
    # Existing student should not be altered
    assert_equal_attributes User.find_by_studentnumber('00001'), {:studentnumber => '00001', :firstname => 'Student', :lastname => '1', :email => 'student1@example.com'}
    assert instance.students.include?(users(:student1)), "Existing user (student1) was not added to the course"
    
    # Existing student should be added to the course when only studentnumber is given
    assert instance.students.include?(users(:student2)), "Existing user (student2) was not added to the course"
    
    # New student should be created
    user82735 = User.find_by_studentnumber('82735')
    assert_equal_attributes user82735, {:studentnumber => '82735', :firstname => 'Newbie', :lastname => 'Student', :email => 'newstudent@example.com'}
    assert instance.students.include?(user82735), "New user (82735) was not added to the course"
    
    # New student should be created when only studentnumber is given
    user28462 = User.find_by_studentnumber('28462')
    assert user28462, "User was not created when only studentnumber was given"
    assert instance.students.include?(user28462), "New user (28462) was not added to the course"
  end
  
end
