class TestMailer < ActionMailer::Base
  default :from => RUBYRIC_EMAIL
  default_url_options[:host] = RUBYRIC_HOST
  
  def test_email(address, options = {})
    @delayed = options[:delayed]
    mail(:subject => "[Rubyric] Mailer test", :to => RUBYRIC_EMAIL)
  end

end
