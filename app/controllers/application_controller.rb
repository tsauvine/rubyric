class ApplicationController < ActionController::Base
  protect_from_forgery

  helper :all # include all helpers, all the time
  helper_method :current_session, :current_user, :logged_in?, :is_admin?

  # SSL
  before_filter :redirect_to_ssl
  def redirect_to_ssl
    redirect_to :protocol => "https://" if FORCE_SSL && !request.ssl?
  end
  
  # Locale
  before_filter :set_locale
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


  protected

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
  
  def login_required
    unless current_user
      store_location
      
      # TODO: use shibboleth
      redirect_to new_session_url
      
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
      render :template => 'shared/forbidden', :status => 403
    else
      # If not logged in, redirect to login
      respond_to do |format|
        format.html do
          store_location
          redirect_to new_session_path
        end
        format.any do
          request_http_basic_authentication 'Web Password'
        end
      end
    end
    
    return false
  end

#   def require_no_user
#     if current_user
#       store_location
#       
#       flash[:error] = "You must be logged out to access"
#       redirect_to root_url
#       
#       return false
#     end
#   end
  
  def store_location
    session[:return_to] = request.fullpath
  end
  
  def redirect_back_or_default(default)
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end
  
end
