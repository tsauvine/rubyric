class CourseInstance < ActiveRecord::Base
  belongs_to :course
  has_many :exercises, {:order => :id, :dependent => :destroy}

  has_and_belongs_to_many :students, {:class_name => 'User', :join_table => 'course_instances_students', :order => :studentnumber}
  has_and_belongs_to_many :assistants, {:class_name => 'User', :join_table => 'assistants_course_instances', :order => :studentnumber}

  validates_presence_of :name

  # TODO:
  # attr_accessible :name, :description, :active

  def has_assistant(user)
    user && assistants.include?(user)
  end

  def add_students_csv(csv)
    add_users_csv(csv, students)
  end

  def add_assistants_csv(csv)
    add_users_csv(csv, assistants)
  end


  # Raises an exception if adding the user fails.
  def add_user_hash(h, collection)
    if !h[:login] && !h[:studentnumber]
      raise ArgumentError.new("New user has neither login nor student number")
    end
    u = nil
    u = User.find_by_login(h[:login]) if h[:login]
    u ||= User.find_by_studentnumber(h[:studentnumber]) if h[:studentnumber]

    if u
      collection << u unless collection.include?(u)
    else

      # User does not exist yet in the database
      u = User.new
      u.studentnumber = h[:studentnumber]
      u.firstname = h[:firstname]
      u.lastname = h[:lastname]
      u.email = h[:email]
      u.password = h[:password]
      u.login = h[:login]
      u.save! # raise an exception if something fails
      collection << u
    end

  end


  def add_users_csv(csv, collection)

    array = csv.split(/\r?\n|\r(?!\n)/)

    #csv.each_line do |line|
    User.transaction do
      array.each do |line|
        next if line.empty?

        parts = line.split(',',6).map { |s| s.strip }
        user_hash = {}
        [:studentnumber,
         :firstname,
         :lastname,
         :email,
         :password,
         :login].each_with_index do |data, idx|
          user_hash[data] = parts[idx]
        end
        self.add_user_hash(user_hash, collection)
      end
      return true
    end
  end


  # Removes students from the course instance. The parameter can be
  # an array of user ids or an array of user objects.
  # Returns the number of students removed
  def remove_students(users)
    counter = 0

    users.each do |user|
      counter += remove_student(user)
    end

    return counter
  end

  # Removes a student from the course instance. The parameter can be
  # a user id or a user object
  def remove_student(user)
    user = User.find(user) unless user.is_a?(User)
    students.delete(user)
    return 1

    rescue
      return 0
  end

  # Removes assistants from the course instance. The parameter can be
  # an array of user ids or an array of user objects.
  # Returns the number of assistants removed
  def remove_assistants(users)
    counter = 0

    users.each do |user|
      counter += remove_assistant(user)
    end

    return counter
  end

  # Removes a student from the course instance. The parameter can be
  # a user id or a user object
  def remove_assistant(user)
    user = User.find(user) unless user.is_a?(User)
    assistants.delete(user)
    return 1

    rescue
      return 0
  end

  def disk_space
    sum = 0
    exercises.each {|e| sum += e.disk_space }
    sum
  end

  def groups_count
    sum = 0
    exercises.each {|e| sum += e.groups.size }
    sum
  end

  def submissions_count
    sum = 0
    exercises.each {|e| sum += e.submissions.size }
    sum
  end

end
