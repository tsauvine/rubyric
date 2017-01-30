class CourseInstance < ActiveRecord::Base
  belongs_to :course
  has_many :exercises, dependent: :destroy
  has_many :groups

  has_and_belongs_to_many :students, class_name: 'User', join_table: 'course_instances_students'
  has_and_belongs_to_many :assistants, class_name: 'User', join_table: 'assistants_course_instances'

  validates_presence_of :name
  validate :check_agree_terms
  validates :lti_context_id, uniqueness: { scope: :lti_consumer, message: "context ID already taken", allow_blank: true }

  belongs_to :pricing

  # TODO:
  #attr_accessible :name, :description, :active, :locale, :submission_policy, :lti_consumer, :lti_context_id, :lti_resource_link_id, :agree_terms
  attr_accessor :agree_terms

  def check_agree_terms
    errors.add(:agree_terms, "Please read the terms and conditions") unless agree_terms == '1'
  end

  def has_assistant(user)
    user && assistants.include?(user)
  end

  def has_student(user)
    user && students.include?(user)
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

  # Creates example groups for this course instance. Group members are users whose firstname is 'Student' and organization is 'Example'.
  def create_example_groups(groups_count = 100)
    # FIXME: What if Example organization is not found?
    organization = Organization.where(:name => 'Example').first

    # Get example students
    users = User.where(:firstname => 'Student', :organization_id => organization.id).all
    user_counter = 0

    # Create groups and submissions
    for i in (1..groups_count)
      # Create group
      group = Group.new(:course_instance_id => self.id, :name => "Group #{i}", :max_size => 3)
      group.save(:validate => false)

      # Add users to group
      students_count = rand(3) # self.groupsizemin + rand(self.groupsizemax - self.groupsizemin + 1)
      for j in (0..students_count)
        user = users[user_counter]
        group.add_member(user) if user
        user_counter += 1
      end

      break if user_counter >= users.size
    end
  end

  # assignments: {group_id => [user_id, user_id, ...], group_id => ...}
  def set_assignments(assignments)
    return unless assignments

    Group.transaction do
      self.groups.includes(:reviewers).find_each do |group|
        group.reviewer_ids = assignments[group.id.to_s] || []
        group.save
      end
    end
  end

  # Creates groups and adds them to the course based on a list of studentnumebrs or emails.
  # batch: string with comma separated student identifiers, each row representing one group. Student identifier can be studentnumber or email.
  def batch_create_groups(batch)
    # Load existing students
    students_by_studentnumber = {}  # 'studentnumber' => User
    students_by_lti_user_id = {}
    students_by_email = {}          # 'email' => User
    self.students.each do |student|
      students_by_studentnumber[student.studentnumber] = student
      students_by_lti_user_id[student.lti_user_id] = student
      students_by_email[student.email] = student
    end

    # Load existing groups
    groups_by_student_id = {}     # student_id => [array of groups where the student belongs]
    self.groups.includes(:users, :reviewers).each do |group|
      group.users.each do |student|
        groups_by_student_id[student.id] ||= []
        groups_by_student_id[student.id] << group
      end
    end

    # Load assistants
    reviewers = {}   # key => User
    reviewers_ambiguous_keys = {}
    reviewer_keys = [:email, :studentnumber] # , :firstname, :lastname, :name
    (self.course.teachers + self.assistants + self.students).each do |user|
      # Ignore LTI users as they cause problems because of duplicate email addresses.
      # This check can be removed if an email address is not saved for LTI users.
      next unless user.lti_user_id.blank?

      reviewer_keys.each do |key|
        value = user.send(key)
        next unless value
        value = value.downcase.strip

        # Save the key if it's not already reserved to another user
        if !reviewers[value] || reviewers[value] == user
          reviewers[value] = user
        else
          reviewers_ambiguous_keys[value] = true
        end
      end
    end

    batch.lines.each do |line|
      parts = line.split(';')
      student_keys = parts[0].split(',')

      # Find or create students
      group_students = []   # Array of User objects that were loaded or created based on the input row
      group_student_ids = []
      current_groups = []   # Array of arrays of Groups, [[groups of first student], [groups of second student], ...]
      student_keys.each do |student_key|
        student_key.strip!
        next if student_key.empty?

        student = nil
        if student_key.include?('@')
          # Search by email
          search_key = student_key
          student = students_by_email[search_key]         # Search from students in the course

          unless student
            student = User.where(:email => search_key).first   # Search from database
            unless student  # Create new user
              student = User.new(:email => search_key, :firstname => '', :lastname => '')
              student.organization_id = self.course.organization_id
              student.save(:validate => false)
            end
            self.students << student  # Add student to course
            students_by_studentnumber[student.studentnumber] = student
            students_by_email[student.email] = student
          end

        else
          # Search by studentnumber
          search_key = student_key
          student = students_by_studentnumber[search_key] || students_by_lti_user_id[search_key]       # Search from students in the course

          unless student
            relation = User.where(:studentnumber => search_key) # Search from database
            # relation = relation.where(:organization_id => self.course.organization_id) if self.course.organization_id
            student = relation.first

            # Create new user
            if !student && self.submission_policy != 'lti'
              student = User.new(:firstname => '', :lastname => '')
              student.studentnumber = search_key
              student.organization_id = self.course.organization_id
              student.save(:validate => false)
            end

            if student
              self.students << student  # Add student to course
              students_by_studentnumber[student.studentnumber] = student
              students_by_email[student.email] = student
            end
          end
        end

        if student
          g = groups_by_student_id[student.id] || []
          current_groups << g
          group_students << student
          group_student_ids << student.id
        end
      end

      next if group_students.empty?

      # Calculate the intersection of students' current groups, ie. find the groups that contain all of the given students.
      groups = current_groups.inject(:&)

      # The list now contains the groups with the requested students but possibly extra students as well.
      # Find the group that contains the requested amount of students.
      group = nil
      groups.each do |g|
        if g.users.size == group_students.size
          group = g
          break
        end
      end

      # Create group if not found
      unless group
        group_name = (group_students.collect { |user| user.studentnumber }).join('_')
        group = Group.new(:name => group_name, :course_instance_id => self.id, :max_size => group_students.size)
        group.save(:validate => false)

        group_students.each do |student|
          member = GroupMember.new(:email => student.email, :studentnumber => student.studentnumber)
          member.group = group
          member.user = student
          member.save(:validate => false)
          group.group_members << member

          groups_by_student_id[student.id] ||= []
          groups_by_student_id[student.id] << group
        end
      end

      # Set reviewers
      if parts.size >= 2
        reviewer_keys = parts[1].split(',')

        reviewer_keys.each do |reviewer_key|
          reviewer_key = reviewer_key.strip.downcase
          next if reviewer_key.blank?

          # Detect ambiguous keys
          if reviewers_ambiguous_keys[reviewer_key]
            # TODO: warn about ambiguous key
            logger.debug "Ambiguous key #{reviewer_key}"
            next
          end

          reviewer = reviewers[reviewer_key]
          unless reviewer
            # TODO: warn that reviewer was not found
            logger.debug "Reviewer #{reviewer_key} not found"
            next
          end

          group.reviewers << reviewer unless group.reviewers.include? reviewer
        end
      end
    end
  end

end
