# This controller handles the login/logout function of the site.
class SessionsController < ApplicationController
  # render new.rhtml
  def new
    logger.info("Logout url: #{request.env['HTTP_X_LOGOUTURL']}")
  end

  # Shibboleth login. Checks the HTTP headers to see if the user is authenticated
  # with Shibboleth. Initializes the session if this is the case. A new user is created
  # if user is not found from the database.
  def shibboleth
#     shibinfo = {
#       :login => 'tteekkar@hut.fi',
#       :studentnumber => ('urn:mace:terena.org:schac:personalUniqueCode:fi:tkk.fi:student:12345S' || '').split(':').last,
#       :firstname => 'Teemu',
#       :lastname => 'Teekkari',
#       :email => 'tteekkar@cs.hut.fi',
#       :organization => 'hut.fi'
#     }

    shibinfo = {
      :login => request.env['HTTP_EPPN'],
      :studentnumber => (request.env['HTTP_SCHACPERSONALUNIQUECODE'] || '').split(':').last,
      :firstname => request.env['HTTP_DISPLAYNAME'],
      :lastname => request.env['HTTP_SN'],
      :email => request.env['HTTP_MAIL'],
      :organization => request.env['HTTP_SCHACHOMEORGANIZATION']
    }

    session[:logout_url] = request.env['HTTP_LOGOUTURL']

    if shibinfo[:login].blank? && shibinfo[:studentnumber].blank?
      flash[:error] = "Shibboleth login failed. No username or studentnumber was received."
      logger.warn("Shibboleth login failed (missing attributes). #{shibinfo}")
      render :action => 'new'
      return
    end

    # Find user
    user = User.find_by_login(shibinfo[:login]) unless shibinfo[:login].blank?

    # If user was not found by login, search with student number.
    # This happens when a student has been created with studentnumber as part of a group, and now logs in for the first time.
    if !user && !shibinfo[:studentnumber].blank?
      # Login must be null, otherwise the account may belong to someone else.
      user = User.find_by_studentnumber(shibinfo[:studentnumber], :conditions => "login IS NULL")
    end
    
    # Aalto migration
    if !user
      new_parts = shibinfo[:login].split('@')
      new_login = new_parts[0]
      new_domain = new_parts[1]
      
      if new_domain == 'aalto.fi'
        user = User.find_by_login(new_login + '@hut.fi')
        
        if user
          logger.info("Aalto migration #{user.login} -> #{new_login}@aalto.fi (id #{user.id})")
          user.login = new_login + '@aalto.fi'
        end
      end
    end

    # Create new account or update an existing
    unless user
      # New user
      user = User.new(shibinfo)
      user.login = shibinfo[:login]
      if user.save
        logger.info("Created new user #{user.login} (#{user.studentnumber}) (shibboleth)")
      else
        logger.warn("Failed to create new user (shibboleth) #{shibinfo}. #{user.errors.full_messages.join('. ')}")
        flash[:error] = 'Failed to create new user'
        render :action => 'new'
        return
      end
    else
      # Update metadata
      shibinfo.each do |key, value|
        user.write_attribute(key, value) if user.read_attribute(key).blank?
      end
      user.save
    end

    # Log in
    logger.info("Logged in #{user.login} (#{user.studentnumber}) (shibboleth)")
    self.current_user = user

    # Redirect back
    redirect_back_or_default(root_url)
  end

  # Authenticates the user with password and initializes the session if
  # the password is correct.
  def create
    self.current_user = User.authenticate(params[:studentnumber], params[:password])
    if logged_in?
      if params[:remember_me] == "1"
        current_user.remember_me unless current_user.remember_token?
        cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
      end
      redirect_back_or_default(root_url)
    else
      flash[:error] = "Invalid password or not registered"
      render :action => 'new'
    end
  end

  def destroy
    logout_url = session[:logout_url]
    self.current_user.forget_me if logged_in?
    cookies.delete :auth_token
    reset_session
    flash[:success] = "You have been logged out."

    if logout_url
      redirect_to(logout_url)
    else
      redirect_back_or_default(root_url)
    end
  end

end
