class GroupMember < ActiveRecord::Base

  belongs_to :group
  belongs_to :user

  # attr_accessible :email, :studentnumber
  validates :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i } #, :allow_blank => true

  #before_save :generate_token
  #before_validation :strip_whitespace
  before_save :renew_token
  after_save :send_invitation_delayed

#   def strip_whitespace
#     self.email.strip! unless self.email.blank?
#   end

  def studentnumber
    self.user ? user.studentnumber : read_attribute(:studentnumber)
  end

  def name
    self.user ? user.name : ''
  end

  def firstname
    self.user ? user.firstname : ''
  end

  def lastname
    self.user ? user.lastname : ''
  end

  # Generates a unique token
  def generate_token
    begin
      self.access_token = Digest::SHA1.hexdigest([Time.now, rand].join)
    end while GroupMember.exists?(:access_token => self.access_token)
  end

  def renew_token
#     user = User.find_by_email(self.email)
#
#     if user
#       self.user = user
#       self.group.course_instance.students << user unless self.group.course_instance.students.include?(user)
#     end

    generate_token() if self.email_changed?
  end

  def send_invitation_delayed
    return if self.user_id  # Don't send invitation if student is already authenticated

    GroupMember.delay.send_invitation(self.id, self.group.exercise_id) if self.email_changed?
  end

  # Sends the invitation mail
  def self.send_invitation(group_member_id, exercise_id)
    begin
      InvitationMailer.group_invitation(group_member_id, exercise_id).deliver
    rescue Exception => e
      logger.error "Failed to send group invitation #{group_member_id}"
      logger.error e
    end
  end

  def authenticated()
    user = User.find_by_email(self.email)
    unless user
      user = User.new(:email => self.email)
      user.save(:validate => false)
    end

    self.user = user
    self.studentnumber = user.studentnumber
    self.save

    self.group.course_instance.students << user unless self.group.course_instance.students.include?(user)
  end

end
