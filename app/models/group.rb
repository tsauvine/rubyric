class Group < ActiveRecord::Base
  belongs_to :exercise
  has_and_belongs_to_many :users
  has_many :submissions, {:order => 'created_at DESC', :dependent => :destroy}

  def has_member?(user)
    user && users.include?(user)
  end

  # Adds members to the group.
  #
  # If some student is not found from the database, a new user is created.
  # The user will later take over that account when logging in with shibboleth.
  #
  # members is an array of {:studentnumber, :email} hashes.
  def add_members(members)
    group = nil

    members.each do |member|
      # Find user
      user = User.find_by_studentnumber(member[:studentnumber])

      unless user
        # Create new user
        user = User.new(:studentnumber => member[:studentnumber], :email => member[:email])
        user.save
      end

      # Add to the group
      self.users << user

      # Add student to the course instance
      collection = exercise.course_instance.students
      collection << user unless collection.include?(user)
    end
  end



end
