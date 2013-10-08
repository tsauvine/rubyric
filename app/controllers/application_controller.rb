require 'custom_logger'
require 'client_event_logger'
require 'securerandom.rb'

# Rubyric
class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details
  
  helper_method :current_session, :current_user, :logged_in?, :is_admin?

  before_filter :redirect_to_ssl
  before_filter :set_locale
  before_filter :require_login?
  
  def log_client_event
    ClientEventLogger.info("#{params[:session]} #{params[:events]}")
    
    render :nothing => true, :status => :ok
  end
  
  protected
  
  def log(message)
    user = current_user
    
    if user
      CustomLogger.info("#{user.login || user.email} " + message)
    else
      CustomLogger.info('guest ' + message)
    end
  end
  
  # Redirects from http to https if FORCE_SSL is set.
  def redirect_to_ssl
    redirect_to :protocol => "https://" if FORCE_SSL && !request.ssl?
  end
  
  # Locale
  def set_locale
    if params[:locale]  # Locale is given as a URL parameter
      I18n.locale = params[:locale]
      
      # Save the locale into session
      session[:locale] = params[:locale]

      # Save the locale in user's preferences
      #if logged_in?
      #  current_user.locale = params[:locale]
      #  current_user.save
      #end
    #elsif logged_in? && !current_user.locale.blank?  # Get locale from user's preferences
    #  I18n.locale = current_user.locale
    elsif !session[:locale].blank?  # Get locale from session
      I18n.locale = session[:locale]
    end
  end
  
#   def default_url_options(options={})
#     if params[:embed]
#       return { :embed => 'embed' }
#     else
#       return { :embed => false }
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

  private
  
  def current_session
    return @current_session if defined?(@current_session)
    @current_session = Session.find
  end
  
  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_session && current_session.record
  end
  
  def logged_in?
    !!current_user
  end
  
  def is_admin?(user)
    user && user.admin
  end
  
  def store_location
    session[:return_to] = request.fullpath
  end
  
  def redirect_back_or_default(default)
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end
  
  # If require_login GET-parameter is set, this filter redirect to login. After successful login, user is redirected back to the original location.
  def require_login?
    login_required if params[:require_login] && !logged_in?
  end

  def login_required
    unless current_user
      store_location
      
      # FIXME: make this course specific
#       if defined?(SHIB_PATH)
#         redirect_to SHIB_PATH + shibboleth_session_url(:protocol => 'https')
#       else
        redirect_to new_session_url
#       end
      
      return false
    end
  end
  
  rescue_from CanCan::AccessDenied do |exception|
    access_denied
  end
  
  def access_denied
    if request.xhr?
      head :forbidden
    elsif logged_in?
      render :template => 'shared/forbidden', :status => 403, :layout => 'wide'
    else
      # If not logged in, redirect to login
      respond_to do |format|
        format.html do
          store_location
          
#           if defined?(SHIB_PATH)
#             redirect_to SHIB_PATH + shibboleth_session_url(:protocol => 'https')
#           else
            redirect_to new_session_url
#           end
        end
        format.any do
          request_http_basic_authentication 'Web Password'
        end
      end
    end
    
    return false
  end
  
  # Send email on exception
  rescue_from Exception do |exception|
    begin
      # Send email
      if ERRORS_EMAIL && Rails.env == 'production' && !(exception.is_a?(ActionController::RoutingError))
        ErrorMailer.snapshot(exception, params, request).deliver
      end
    rescue => e
      logger.error e
    end
    
    raise exception
  end

end
