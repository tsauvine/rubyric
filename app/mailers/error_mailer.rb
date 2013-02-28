class ErrorMailer < ActionMailer::Base
  default :from => RUBYRIC_EMAIL
  default_url_options[:host] = RUBYRIC_HOST
  
  def snapshot(exception, trace, params, request)
    @exception  = exception
    @trace      = trace
    @params     = params
    @request    = request
    @env        = request.env
    
    mail(:to => ERRORS_EMAIL, :subject => "[Error] Rubyric exception in #{request.env['REQUEST_URI']}")
  end

end
