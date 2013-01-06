class Group < ActiveRecord::Base
  belongs_to :exercise
  belongs_to :course_instance

  has_and_belongs_to_many :users
  has_many :group_invitations
  has_many :submissions, {:order => 'created_at DESC', :dependent => :destroy}

  has_many :group_reviewers
  has_many :reviewers, :through => :group_reviewers, :source => :user, :class_name => 'User'

  def has_member?(user)
    user && users.include?(user)
  end

  # Adds members to the group.
  #
  # If some student is not found from the database, a new user is created.
  # The user will later take over that account when logging in with shibboleth.
  #
  # OBSOLETE: studentnumber cannot be used as a unique identifier
  #
  # members is an array of {:studentnumber, :email} hashes.
#   def add_members(members)
#     members.each do |member|
#       # Find user
#       user = User.find_by_studentnumber(member[:studentnumber])
# 
#       unless user
#         # Create new user
#         user = User.new(:studentnumber => member[:studentnumber], :email => member[:email])
#         user.save
#       end
# 
#       # Add to the group
#       self.users << user
# 
#       # Add student to the course instance
#       collection = exercise.course_instance.students
#       collection << user unless collection.include?(user)
#     end
#   end

  # If matching email address if found, user is added to the group. Otherwise, an invitation link is sent to that address.
  #
  # members: array of email addresses
  def add_members_by_email(addresses, exercise)
    addresses.each do |address|
      user = User.find_by_email(address)

      if user
        self.users << user unless self.users.include?(user)
      else
        # Create invitation
        invitation = GroupInvitation.create(
          :group_id => self.id,
          :exercise_id => exercise.id,
          :token => Digest::SHA1.hexdigest([Time.now, rand].join),
          :email => address,
          :expires_at => Time.now + 1.weeks)

        #GroupInvitationMailer.invitation(invitation.id).deliver

        # Send invitation link with delayed_job
        GroupInvitationMailer.delay.invitation(invitation.id)
      end
    end

  end

end
