class ErrorMailer < ActionMailer::Base
  default :from => RUBYRIC_EMAIL, :to => ERRORS_EMAIL
  default_url_options[:host] = RUBYRIC_HOST
  
  def snapshot(exception, params, request)
    @exception  = exception
    @params     = params
    @request    = request
    @env        = request.env

    mail(:subject => "[Rubyric] Exception in #{request.env['REQUEST_URI']}")
  end
  
  def long_mail_queue
    mail(:subject => "[Rubyric] Long mail queue")
  end

end
