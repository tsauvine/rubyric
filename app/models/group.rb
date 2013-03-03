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
  
  def has_reviewer?(user)
    user && reviewers.include?(user)
  end

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

        # Send invitation link
        if ENABLE_DELAYED_JOB
          InvitationMailer.delay.group_invitation(invitation.id)
        else
          begin
            InvitationMailer.group_invitation(invitation.id).deliver
          rescue
            # TODO
          end
        end
      end
    end

  end

end
