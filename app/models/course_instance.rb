class CourseInstance < ActiveRecord::Base
  belongs_to :course
  has_many :exercises, {:order => :deadline, :dependent => :destroy}
  has_many :groups
  
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
    
    user = nil
    user = User.find_by_login(h[:login]) if h[:login]
    user ||= User.find_by_studentnumber(h[:studentnumber]) if h[:studentnumber]

    if user
      # Existing user
      collection << user unless collection.include?(user)
    else
      # New user
      user = User.new
      user.studentnumber = h[:studentnumber]
      user.firstname = h[:firstname]
      user.lastname = h[:lastname]
      user.email = h[:email]
      user.password = h[:password]
      user.login = h[:login]
      
      user.save! # raise an exception if something fails
      
      collection << user
    end

  end


  def add_users_csv(csv, collection)
    # Convert Mac newlines
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
    end
    
    return true
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

  # Creates an example course, instance and submissions.
  def create_example_groups(groups_count = 100)
    #groups_count = 100 unless groups_count
    
    # Get example students
    users = User.where(:firstname => 'Student').all
    user_counter = 0
    
    # Create groups and submissions
    for i in (1..groups_count)
      # Create group
      group = Group.create(:course_instance_id => self.id, :name => "Group #{i}")

      # Add users to group
      students_count = self.groupsizemin + rand(self.groupsizemin - self.groupsizemax + 1)
      for j in (0..students_count)
        user = users[user_counter]
        group.users << user if user
        user_counter += 1
      end

      break if user_counter >= users.size
    end
  end
end
