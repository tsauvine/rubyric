class Group < ActiveRecord::Base
  belongs_to :exercise
  belongs_to :course_instance

  has_and_belongs_to_many :users
  has_many :group_invitations
  
  has_many :submissions, {:order => 'created_at DESC', :dependent => :destroy}

  has_many :group_reviewers
  has_many :reviewers, :through => :group_reviewers, :source => :user, :class_name => 'User'

  attr_accessor :url
  
  def has_member?(user)
    user && users.include?(user)
  end
  
  def has_reviewer?(user)
    user && reviewers.include?(user)
  end

  def add_member(user)
    self.users << user unless self.users.include?(user)
    self.course_instance.students << user unless self.course_instance.students.include?(user)
  end
  
  # If matching email address if found, user is added to the group. Otherwise, an invitation link is sent to that address.
  #
  # members: array of email addresses
  def add_members_by_email(addresses, exercise)
    addresses.each do |address|
      user = User.find_by_email(address)

      if user
        self.users << user unless self.users.include?(user)
        self.course_instance.students << user unless self.course_instance.students.include?(user)
      else
        # Create invitation
        invitation = GroupInvitation.create(
          :group_id => self.id,
          :exercise_id => exercise.id,
          :email => address
        )
      end
    end

  end

end
