class SessionsController < ApplicationController
  #before_filter :require_no_user, :only => [:new, :create]
  #before_filter :require_user, :only => :destroy

  layout 'narrow'

  def new
    @session = Session.new
  end

  def create
    @session = Session.new(params[:session])

    session[:logout_url] = nil

    if @session.save
      logger.info "Login successful"
      redirect_back_or_default root_url
    else
      logger.info "Login failed. #{@session.errors.full_messages.join(',')}"
      flash[:error] = t('sessions_login_failed')
      render :action => :new
    end
  end

  def destroy
    logout_url = session[:logout_url]

    session = current_session
    return unless session

    session.destroy
    flash[:success] = "Logout successful"

    if logout_url
      redirect_to(logout_url)
    else
      redirect_to(root_url)
    end
  end


  def shibboleth
    shibinfo = {
      :login => request.env[SHIB_ATTRIBUTES[:id]],
      :studentnumber => (request.env[SHIB_ATTRIBUTES[:studentnumber]] || '').split(':').last,
      :firstname => request.env[SHIB_ATTRIBUTES[:firstname]],
      :lastname => request.env[SHIB_ATTRIBUTES[:lastname]],
      :email => request.env[SHIB_ATTRIBUTES[:email]],
    }
    session[:logout_url] = request.env[SHIB_ATTRIBUTES[:logout]]

#     shibinfo = {
#       :login => '83632', #'student1@hut.fi',
#       :studentnumber => ('urn:mace:terena.org:schac:personalUniqueCode:fi:tkk.fi:student:83632' || '').split(':').last,
#       :firstname => 'Teemu',
#       :lastname => 'Teekkari',
#       :email => 'tteekkar@cs.hut.fi'
#     }
#     logout_url= 'http://www.aalto.fi/'

    shibboleth_login(shibinfo, logout_url)
  end


  def shibboleth_login(shibinfo, logout_url)
    if shibinfo[:login].blank? && shibinfo[:studentnumber].blank?
      flash[:error] = "Shibboleth login failed (no studentnumber or username received)."
      render :action => 'new'
      return
    end

    session[:logout_url] = logout_url

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

    # Create new account or update an existing
    unless user
      logger.debug "User not found. Trying to create."

      # New user
      user = User.new()
      user.login = shibinfo[:login]
      user.studentnumber = shibinfo[:studentnumber]
      user.firstname = shibinfo[:firstname]
      user.lastname = shibinfo[:lastname]
      user.email = shibinfo[:email]
      user.organization = shibinfo[:organization]
      if user.save(:validate => false)
        logger.info("Created new user #{user.login} (#{user.studentnumber}) (shibboleth)")
      else
        logger.info("Failed to create new user (shibboleth) #{shibinfo} Errors: #{user.errors.full_messages.join('. ')}")
        flash[:error] = 'Failed to create new user'
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
      user.organization = shibinfo[:organization] if user.organization.blank?

      #user.save
    end

    # Create session
    user.reset_persistence_token  # Authlogic won't work if persistence token is empty
    if Session.create(user)
      logger.info("Logged in #{user.login} (#{user.studentnumber}) (shibboleth)")
    else
      logger.warn("Failed to create session for #{user.login} (#{user.studentnumber}) (shibboleth)")
      flash[:error] = 'Shibboleth login failed.'
      render :action => 'new'
      return
    end

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
end
