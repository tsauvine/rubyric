class PasswordMailer < ActionMailer::Base
  default :from => RUBYRIC_EMAIL
  default_url_options[:host] = RUBYRIC_HOST
  
  def password_reset_instructions(user_id)
    @user = User.find(user_id)
    
    mail(:to => @user.email, :subject => "Reset Rubyric password") if @user
  end
  
end
