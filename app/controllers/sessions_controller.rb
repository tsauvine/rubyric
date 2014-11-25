require 'cgi'
require 'ims/lti'
require 'oauth/request_proxy/rack_request'

# Rubyric
class SessionsController < ApplicationController
  #before_filter :require_no_user, :only => [:new, :create]
  #before_filter :require_user, :only => :destroy

  layout 'narrow-new'

  def new
    @session = Session.new
  end

  def create
    @session = Session.new(params[:session])

    session[:logout_url] = nil

    if @session.save
      logger.info "Login successful"
      redirect_back_or_default root_url
      
      CustomLogger.info("#{current_user.login} login_traditional success")
    else
      logger.info "Login failed. #{@session.errors.full_messages.join(',')}"
      #flash[:error] = t('sessions_login_failed')
      render :action => :new
      
      CustomLogger.info("guest login_traditional fail #{@session.errors.full_messages.join(',')}")
    end
  end

  def destroy
    unless current_session
      redirect_to(root_url)
      return
    end
    
    logout_url = session[:logout_url]
    current_session.destroy

    if logout_url
      redirect_to(logout_url)
    else
      redirect_to(root_url)
    end
    
    log "logout"
  end


  def shibboleth
    if defined?(SHIB_ATTRIBUTES)
      shibinfo = {
        :login => request.env[SHIB_ATTRIBUTES[:id]],
        :studentnumber => (request.env[SHIB_ATTRIBUTES[:studentnumber]] || '').split(':').last,
        :firstname => request.env[SHIB_ATTRIBUTES[:firstname]],
        :lastname => request.env[SHIB_ATTRIBUTES[:lastname]],
        :email => request.env[SHIB_ATTRIBUTES[:email]],
        :logout_url => request.env[SHIB_ATTRIBUTES[:logout]]
      }
    elsif Rails.env == 'development'
      shibinfo = {
        :login => 'student41@aalto.fi', #'student1@hut.fi',
        :studentnumber => ('urn:mace:terena.org:schac:personalUniqueCode:fi:tkk.fi:student:00041' || '').split(':').last,
        :firstname => 'Student',
        :lastname => '41',
        :email => 'student41@example.com',
        :logout_url => 'http://www.aalto.fi/'
      }
    else
      shibinfo = {}
    end

    shibboleth_login(shibinfo)
  end


  def shibboleth_login(shibinfo)
    if shibinfo[:login].blank? && shibinfo[:studentnumber].blank?
      flash[:error] = "Shibboleth login failed (no studentnumber or username received)."
      logger.warn("Shibboleth login failed (missing attributes). #{shibinfo}")
      render :action => 'new'
      return
    end

    # Find user by username (eppn)
    unless shibinfo[:login].blank?
      logger.debug "Trying to find by login #{shibinfo[:login]}"
      user = User.find_by_login(shibinfo[:login])
    end

    # If user was not found by login, search with student number. (User may have been created as part of a group, but has never actually logged in.)
    # Login must be null, otherwise the account may belong to someone else from another organization.
    if !user && !shibinfo[:studentnumber].blank?
      logger.debug "Trying to find by studentnumber #{shibinfo[:studentnumber]}"
      user = User.find_by_studentnumber(shibinfo[:studentnumber], :conditions => "login IS NULL")
    end
    
    if !user && !shibinfo[:email].blank?
      logger.debug "Trying to find by email #{shibinfo[:email]}"
      user = User.find_by_email(shibinfo[:email])
    end
    
    # Create new account or update an existing
    unless user
      logger.debug "User not found. Trying to create."

      # Find organization
      organization_domain = (shibinfo[:login] || '').split('@',2)[1]
      
      # New user
      user = User.new()
      user.login = shibinfo[:login]
      user.studentnumber = shibinfo[:studentnumber]
      user.firstname = shibinfo[:firstname]
      user.lastname = shibinfo[:lastname]
      user.email = shibinfo[:email]
      user.organization = Organization.find_by_domain(organization_domain) || Organization.create(domain: organization_domain) if organization_domain
      user.reset_persistence_token
      #user.reset_single_access_token
      if user.save(:validate => false)
        logger.info("Created new user #{user.login} (#{user.studentnumber}) (shibboleth)")
        CustomLogger.info("#{user.login} create_user_shib success")
      else
        logger.info("Failed to create new user (shibboleth) #{shibinfo} Errors: #{user.errors.full_messages.join('. ')}")
        flash[:error] = "Failed to create new user. #{user.errors.full_messages.join('. ')}"
        CustomLogger.info("#{user.login} create_user_shib fail")
        render :action => 'new'
        return
      end
    else
      logger.debug "User found. Updating attributes."

      # Update metadata
      user.login = shibinfo[:login] if user.login.blank?
      user.studentnumber = shibinfo[:studentnumber] if user.studentnumber.blank?
      user.firstname = shibinfo[:firstname] if user.firstname.blank?
      user.lastname = shibinfo[:lastname] if user.lastname.blank?
      user.email = shibinfo[:email] if user.email.blank?
      user.reset_persistence_token if user.persistence_token.blank?  # Authlogic won't work if persistence token is empty
      #user.reset_single_access_token if user.single_access_token.blank?
      
      unless user.organization
        organization_domain = (shibinfo[:login] || '').split('@',2)[1]
        user.organization = Organization.find_by_domain(organization_domain) || Organization.create(domain: organization_domain) if organization_domain
      end
    end

    # Create session
    if Session.create(user)
      session[:logout_url] = shibinfo[:logout_url]
      logger.info("Logged in #{user.login} (#{user.studentnumber}) (shibboleth)")
    else
      logger.warn("Failed to create session for #{user.login} (#{user.studentnumber}) (shibboleth)")
      flash[:error] = 'Shibboleth login failed.'
      render :action => 'new'
      return
    end
    CustomLogger.info("#{user.login} login_shib success")

    # Demo registration
    if (params[:demo])
      # Create course
      exercise = Course.create_example(user)
      redirect_to exercise
    else
      # Redirect back
      redirect_back_or_default(root_url)
    end
  end
  
  
  def lti
    return unless authorize_lti
    
    # Find exercise
    organization = Organization.find_by_domain(params['oauth_consumer_key']) || Organization.create(domain: params['oauth_consumer_key'])
    exercise = Exercise.where(:lti_consumer => params['oauth_consumer_key'], :lti_context_id => params[:context_id], :lti_resource_link_id => params[:resource_link_id]).first
    unless exercise
      @heading =  "This course is not configured"
      render :template => "shared/error"
      return
    end
    
    # Find or create user, TODO: handle errors
    user = User.where(:lti_consumer => params['oauth_consumer_key'], :lti_user_id => params[:user_id]).first || create_lti_user(params['oauth_consumer_key'], params[:user_id], organization, exercise.course_instance, params[:custom_student_id])

    # Create or find group, TODO: handle errors
    group = if params[:custom_group_members]
      logger.info("LTI request: #{params[:custom_group_members]}")
      find_or_create_group(JSON.parse(params[:custom_group_members]), exercise, user, organization, params['oauth_consumer_key'])
    else
      find_or_create_group([{'user' => params[:user_id], 'email' => params[:lis_person_contact_email_primary], 'name' => ''}], exercise, user, organization, params['oauth_consumer_key'])
    end

    # Create session
    if Session.create(user)
      session[:logout_url] = params[:launch_presentation_return_url]
      logger.info("Logged in #{params['oauth_consumer_key']}/#{params['user_id']} (LTI)")
    else
      logger.warn("Failed to create session for #{params['oauth_consumer_key']}/#{params['user_id']} (LTI)")
      flash[:error] = 'LTI login failed.'
      render :action => 'new'
      return
    end
    CustomLogger.info("#{params['oauth_consumer_key']}/#{params[:user_id]} login_LTI success")

    # Redirect to submit
    redirect_to submit_path(:exercise => exercise.id, :group => group.id)
  end
  
  
  private
  
  # Returns group
  # payload: [{"user":"lti_user_id","name":"Full Name","email":"user@example.com"},{"user":"lti_user_id","name":"Full Name","email":"user@example.com"}]
  def find_or_create_group(payload, exercise, user, organization, lti_consumer)
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
        group_user = User.where(:lti_consumer => lti_consumer, :lti_user_id => member['user']).first || create_lti_user(lti_consumer, member['user'], organization, exercise.course_instance, member['student_id'])
        logger.debug "Creating member: #{member['user']} #{member['email']}"
        member = GroupMember.new(:email => member['email'])
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
  
  def create_lti_user(oauth_consumer_key, lti_user_id, organization, course_instance, studentnumber)
    logger.debug "Creating user #{lti_user_id}"
    
    user = User.new()
    user.lti_consumer = oauth_consumer_key
    user.lti_user_id = lti_user_id
    user.organization = organization
    user.studentnumber = studentnumber
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
  
  def authorize_lti
    key = params['oauth_consumer_key']
    
    unless key
      @heading =  "No consumer key"
      render :template => "shared/error"
      return false
    end
    
    secret = OAUTH_CREDS[key]
    unless secret
      @tp = IMS::LTI::ToolProvider.new(nil, nil, params)
      @tp.lti_msg = "Your consumer didn't use a recognized key."
      @tp.lti_errorlog = "You did it wrong!"
      @heading =  "Consumer key wasn't recognized"
      render :template => "shared/error"
      return false
    end
    
    @tp = IMS::LTI::ToolProvider.new(key, secret, params)
    
    unless @tp.valid_request?(request)
      @heading =  "The OAuth signature was invalid"
      render :template => "shared/error"
      return false
    end
    
    if Time.now.utc.to_i - @tp.request_oauth_timestamp.to_i > 60*60
      @heading =  "Your request is too old."
      render :template => "shared/error"
      return false
    end
    
    if was_nonce_used_in_last_x_minutes?(@tp.request_oauth_nonce, 60)
      @heading =  "Why are you reusing the nonce?"
      render :template => "shared/error"
      return false
    end
    
    @username = @tp.username("Dude")
    return true
  end
  
  def was_nonce_used_in_last_x_minutes?(nonce, minutes=60)
    # some kind of caching solution or something to keep a short-term memory of used nonces
    false
  end
  
end
