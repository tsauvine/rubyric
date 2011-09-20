# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  # Be sure to include AuthenticationSystem in Application Controller instead
  include AuthenticatedSystem

  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => '15fcb3f437ced87f5b6e714c87e07e66'

  def initialize
    @stylesheets = []
  end

  # See ActionController::Base for details
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password").
  filter_parameter_logging :password

  # SSL
  before_filter :redirect_to_ssl
  def redirect_to_ssl
    redirect_to :protocol => "https://" if FORCE_SSL && !request.ssl?
  end
  
  # Locale
  # before_filter :set_locale
  def set_locale
    if params[:locale]  # Locale is given as a URL parameter
      I18n.locale = params[:locale]
      
      # Save the locale into session
      session[:locale] = params[:locale]

      # Save the locale in user's preferences
      if logged_in?
        current_user.locale = params[:locale]
        current_user.save
      end
    elsif logged_in? && !current_user.locale.blank?  # Get locale from user's preferences
      I18n.locale = current_user.locale
    elsif !session[:locale].blank?  # Get locale from session
      I18n.locale = session[:locale]
    end
  end


  protected

#   def get_stylesheets
#     stylesheets = [] unless stylesheets
#     ["http://www.example.com/stylesheets/#{controller.controller_path}/#{controller.action_name}"].each do |ss|
#       stylesheets << ss if File.exists? "#{Dir.pwd}/public/stylesheets/#{ss}.css"
#     end
#   end


  # If @exercise is defined, loads @course_instance and @course.
  # If @course_instance is defined, loads @course.
  def load_course
    if @exercise
      @course_instance = @exercise.course_instance
    end

    if @course_instance
      @course = @course_instance.course
      
      @is_assistant = @course_instance.has_assistant(current_user)
    end
    
    if @course
      @is_teacher = @course.has_teacher(current_user)
    end
  end

  # Send email on exception
  def log_error(exception)
    super(exception)

    begin
      # Send email
      if ERRORS_EMAIL && !(local_request? || exception.is_a?(ActionController::RoutingError))
        ErrorMailer.deliver_snapshot(exception, clean_backtrace(exception), params, request)
      end
    rescue => e
      logger.error(e)
    end
  end

end
