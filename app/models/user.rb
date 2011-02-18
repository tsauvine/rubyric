class User < ActiveRecord::Base
  acts_as_authentic do |c|
    c.login_field = :studentnumber
    c.validate_password_field = false
    c.validate_email_field = false
    c.transition_from_restful_authentication = true
  end
  
  validates_uniqueness_of :login, :allow_nil => true
  
  attr_accessible :firstname, :lastname, :email, :password, :password_confirmation
  
  has_and_belongs_to_many :groups
  has_many :reviews, :order => 'id'        # reviews as a grader

  # TODO: filter inactive courses
  has_and_belongs_to_many :course_instances_student, {:class_name => 'CourseInstance', :join_table => 'course_instances_students', :order => :course_instance_id}
  has_and_belongs_to_many :course_instances_assistant, {:class_name => 'CourseInstance', :join_table => 'assistants_course_instances', :order => :course_instance_id}
  has_and_belongs_to_many :courses_teacher, {:class_name => 'Course', :join_table => 'courses_teachers', :order => :course_id}

  
  def name
    "#{firstname} #{lastname}"
  end

  def admin?
    self.admin
  end

  def teacher?
    courses_teacher.size > 0
  end

end
