class GroupInvitation < ActiveRecord::Base
  belongs_to :group
  belongs_to :exercise
  
  before_create :generate_token
  
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
    
    GroupInvitation.send_invitation(self.id)
  end
  
  # Send the invitation mail. If ENABLE_DELAYED_JOB, this is executed by delayed_job.
  def self.send_invitation(invitation_id)
    begin
      InvitationMailer.group_invitation(invitation_id).deliver
    rescue Exception => e
      logger.error "Failed to send group invitation #{invitation_id}"
      logger.error e
    end
  end
  handle_asynchronously :send_invitation if ENABLE_DELAYED_JOB

end
