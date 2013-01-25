class Invitation < ActiveRecord::Base
  before_create :generate_token
  
  # Generates a unique token
  def generate_token
    begin
      self.token = Digest::SHA1.hexdigest([Time.now, rand].join)
    end while Invitation.exists?(:token => self.token)
  end

end
