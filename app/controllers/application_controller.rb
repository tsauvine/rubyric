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
    else
      I18n.locale = I18n.default_locale
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
  
  # Returns group
  # payload: [{"user":"lti_user_id","name":"Full Name","email":"user@example.com"},{"user":"lti_user_id","name":"Full Name","email":"user@example.com"}]
  def lti_find_or_create_group(payload, exercise, user, organization, lti_consumer)
    group = nil
    
    # Find groups that the user is part of
    available_groups = Group.where('course_instance_id=? AND user_id=?', exercise.course_instance_id, user.id).joins(:users).order(:name).all
    
    requested_lti_ids = payload.collect {|member| member['user']}
    logger.debug "Requested lti_ids: #{requested_lti_ids}"
    
    # Find the group that matches
    matching_groups = available_groups.select do |group|
      existing_lti_ids = group.users.collect {|user| user.lti_user_id}
      logger.debug "Existing lti_ids: #{existing_lti_ids}"
      
      # Are the arrays identical, ignoring order?
      identical = requested_lti_ids.size == existing_lti_ids.size and requested_lti_ids & existing_lti_ids == requested_lti_ids
      logger.debug "Identical: #{identical}"
      identical
    end
    
    if matching_groups.empty?
      logger.debug "No existing group found. Creating."
      
      groupname = payload.collect{|member| member['email']}.join(', ')
      logger.debug "Groupo name: #{groupname}"
      group = Group.new({:course_instance_id => exercise.course_instance_id, :exercise_id => exercise.id, :name => groupname})
      group.save(:validate => false)
      
      # Create group
      payload.each do |member|
        group_user = User.where(:lti_consumer => lti_consumer, :lti_user_id => member['user']).first || lti_create_user(lti_consumer, member['user'], organization, exercise.course_instance, member['student_id'], nil, nil)
        logger.debug "Creating member: #{member['user']} #{member['email']}"
        member = GroupMember.new(:email => member['email'], :studentnumber => member['student_id'])
        member.group = group
        member.user = group_user
        member.save
      end
    else
      logger.debug "Using existing group."
      # Use existing group
      group = matching_groups.first
    end
    
    group
  end
  
  def lti_create_user(oauth_consumer_key, lti_user_id, organization, course_instance, studentnumber, lastname, firstname)
    logger.debug "Creating user #{lti_user_id}"
    
    user = User.new()
    user.lti_consumer = oauth_consumer_key
    user.lti_user_id = lti_user_id
    user.organization = organization
    user.studentnumber = studentnumber
    user.lastname = lastname
    user.firstname = firstname
    user.reset_persistence_token
    if user.save(:validate => false)
      course_instance.students << user unless course_instance.students.include?(user)
      
      logger.info("Created new user #{oauth_consumer_key}/#{lti_user_id} (LTI)")
      CustomLogger.info("#{oauth_consumer_key}/#{lti_user_id} create_user_lti success")
    else
      logger.info("Failed to create new user (LTI). Errors: #{user.errors.full_messages.join('. ')}")
      flash[:error] = "Failed to create new user. #{user.errors.full_messages.join('. ')}"
      CustomLogger.info("#{oauth_consumer_key}/#{lti_user_id} create_user_lti fail")
      raise "Failed to create user"
    end

    user
  end
  
  
  # Authenticates the LTI request
  # Returns true if the request is legit.
  # Renders an error message and returns false if LTI params are missing or the request is forged.
  def authorize_lti!(options = {})
    # Testing mode
    if Rails.env == 'development' && request.local?
      params['oauth_consumer_key'] = 'aalto.fi'
      params[:context_id] = 'plus.cs.hut.fi/test/test-01/'
      params[:resource_link_id] = 'aplusexercise1412'
      params[:user_id] = '1'
      return true
    end

    return authenticate_lti_signature(options)
  end
  
  
  # Authenticates the LTI signature
  # Returns true if the request is legit.
  # Renders an error message and return false otherwise
  def authenticate_lti_signature(options = {})
    unless params['oauth_consumer_key'] && params[:context_id] && params[:resource_link_id] && params[:user_id]
      @heading =  "Insufficient LTI parameters received"
      render :template => "shared/error"
      return false
    end
    
    consumer_key = params['oauth_consumer_key']
    secret = OAUTH_CREDS[consumer_key]
    unless secret
      @heading =  "LTI error: unrecognized consumer key"
      logger.warn "LTI consumer key for #{consumer_key} has not been configured"
      render :template => "shared/error"
      return false
    end
    
    @tp = IMS::LTI::ToolProvider.new(consumer_key, secret, params)
    
    if !@tp.valid_request?(request)
      @heading =  "LTI error: invalid OAuth signature"
      render :template => "shared/error"
      return false
    end
    
    if @tp.request_oauth_timestamp && (Time.now.utc.to_i - @tp.request_oauth_timestamp.to_i > 60*60)
      @heading =  "LTI error: request too old"
      render :template => "shared/error"
      return false
    end
    
    if was_nonce_used_in_last_x_minutes?(@tp.request_oauth_nonce, 60)
      @heading =  "LTI error: reused nonce"
      render :template => "shared/error"
      return false
    end
    
    return true
  end
  
  def was_nonce_used_in_last_x_minutes?(nonce, minutes=60)
    # some kind of caching solution or something to keep a short-term memory of used nonces
    false
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
          
          # FIXME: hard coded
          if defined?(SHIB_ROOT_PATH) && defined?(@course) && @course.organization_id == 3
            redirect_to "#{SHIB_ROOT_PATH}#{@course.organization.domain.split('.').first}?target=#{shibboleth_session_url(:protocol => 'https')}"
          else
            redirect_to new_session_url
          end
        end
        format.any do
          request_http_basic_authentication 'Web Password'
        end
      end
    end
    
    return false
  end
  
  def group_membership_validated(group)
    if current_user
      logger.debug "Checking current user"
      if group.has_member?(current_user)
        logger.debug "Membership confirmed"
        return true
      end
      
    elsif params[:member_token]
      logger.debug "Checking member token"
      member = GroupMember.find_by_access_token(params[:member_token])
      
      if member && member.group_id == group.id
        log "submit authentication succeeded with member token #{params[:member_token]}"
        return true
      end
    elsif params[:group_token]
      logger.debug "Checking group token"
      grp = Group.find_by_access_token(params[:group_token])
      
      if grp && grp.id == group.id
        log "submit authentication succeeded with group token #{params[:group_token]}"
        return true
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
