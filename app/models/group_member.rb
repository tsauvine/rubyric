class GroupMember < ActiveRecord::Base

  belongs_to :group
  belongs_to :user

  attr_accessible :email
  validates :email, :format => { :with => /^.+@.+\..+$/ } #, :allow_blank => true

  #before_validation :strip_whitespace
  before_save :set_user
  #before_save :generate_token
  after_save :send_invitation_delayed

#   def strip_whitespace
#     self.email.strip! unless self.email.blank?
#   end

  # Generates a unique token
  def generate_token
    begin
      self.access_token = Digest::SHA1.hexdigest([Time.now, rand].join)
    end while GroupMember.exists?(:access_token => self.access_token)
  end
  
  def set_user
    user = User.find_by_email(self.email)

    if user
      self.user = user
      self.group.course_instance.students << user unless self.group.course_instance.students.include?(user)
    end
    
    generate_token() if self.email_changed?
  end
  
  def send_invitation_delayed
    GroupMember.delay.send_invitation(self.id, self.group.exercise_id) if self.email_changed?
    
    if self.email_changed?
      logger.debug "member #{self.email}: email has changed. Sending invitation."
    else
      logger.debug "member #{self.email}: email has not changed."
    end
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
    self.save

    self.group.course_instance.students << user unless self.group.course_instance.students.include?(user)
  end

end
