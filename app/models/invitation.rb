class Invitation < ActiveRecord::Base
  before_create :generate_token
  
  def generate_token
    # Generate a unique token
    while true
      token = Digest::SHA1.hexdigest([Time.now, rand].join)
      break unless Invitation.exists?(:token => token)
    end
    
    self.token = token
  end

end
