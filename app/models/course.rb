class Course < ActiveRecord::Base
  has_many :course_instances, {:order => :id, :dependent => :destroy}
  has_many :active_instances, {:order => :id, :dependent => :destroy, :class_name => 'CourseInstance', :conditions => {:active => true}}
  
  has_and_belongs_to_many :teachers, {:class_name => 'User', :join_table => 'courses_teachers', :order => :studentnumber}
  
  validates_presence_of :code
  validates_presence_of :name

  def has_teacher(user)
    unless user
      logger.info "NO USER GIVEN"
    end
    
    unless teachers.include?(user)
      logger.info "NOT A TEACER ON THIS COURSE"
    end
    
    
    user && teachers.include?(user)
  end

  # Removes teachers from the course. The parameter can be
  # an array of user ids or an array of user objects.
  # Returns the number of users removed
  def remove_teachers(users)
    counter = 0

    users.each do |user|
      counter += remove_teacher(user)
    end

    return counter
  end

  # Removes a teacher from the course instance. The parameter can be
  # a user id or a user object
  def remove_teacher(user)
    user = User.find(user) unless user.is_a?(User)
    teachers.delete(user)
    return 1

    rescue
      return 0
  end

  def email
    address = read_attribute(:email)

    if !address.blank?
      return address
    elsif teachers.size > 0
      return teachers.first.email
    else
      return ''
    end
  end

end
