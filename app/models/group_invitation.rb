class GroupInvitation < ActiveRecord::Base
  # FIXME: class is obsolete
  
  belongs_to :group
  belongs_to :exercise
  
  before_create :generate_token
  
  after_create do |invitation|
    GroupInvitation.delay.send_invitation(invitation.id)
  end
  
  # Generates a unique token
  def generate_token
    self.expires_at = Time.now + 2.weeks
    
    begin
      self.token = Digest::SHA1.hexdigest([Time.now, rand].join)
    end while GroupInvitation.exists?(:token => self.token)
  end

  # Updates the email address and send the invitation mail to the new address
  def update_email(new_email)
    generate_token()
    self.email = new_email
    self.save
    
    GroupInvitation.delay.send_invitation(self.id)
  end
  
  # Sends the invitation mail.
  def self.send_invitation(invitation_id)
    begin
      InvitationMailer.group_invitation(invitation_id).deliver
    rescue Exception => e
      # TODO: mark invitation as invalid
      logger.error "Failed to send group invitation #{invitation_id}"
      logger.error e
    end
  end
  
end
