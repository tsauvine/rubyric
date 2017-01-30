class UsersController < ApplicationController

  before_filter :login_required, :only => [:edit, :update]
  layout 'narrow'

  def new
    # Anyone can create an account
    @user = User.new
    @user.email = params[:email]
    @email_taken = false

    render :action => 'new', :layout => 'narrow-new'
    log "create_user_traditional view"
  end

  def create
    @user = User.new(params[:user])

    if !@user.email.blank? && User.exists?(email: @user.email)
      # User exists, try to log in
      @session = Session.new(params[:user])
      session[:logout_url] = nil

      if @session.save
        CustomLogger.info("#{current_user.login} login_signin success")
        redirect_back_or_default root_url
        return
      else
        @email_taken = true
        render :action => 'new', :layout => 'narrow-new'
        return
      end
    end

    if @user.save
      logger.info("Created user #{@user.email} (traditional)")

      # Login
      #self.current_user = @user
      Session.create(@user)

      # Create course
      exercise = Course.create_example(@user)

      flash[:success] = 'Welcome! An example course has been created for you.'
      redirect_to root_path
      log "create_user_traditional success (example exercise #{exercise})"
    else
      logger.debug @user.errors[:email]
      # Form not sufficiently filled
      render :action => 'new', :layout => 'narrow-new'
      log "create_user_traditional fail #{@user.errors.full_messages.join('. ')}"
    end

  end


  def edit
    if params[:id]
      @user = User.find(params[:id])
    else
      @user = current_user
    end

    return access_denied unless @user == current_user || is_admin?(current_user)

    log "edit_user view"
  end

  def update
    @user = User.find(params[:id])

    return access_denied unless is_admin?(current_user) || @user == current_user

    if @user.update_attributes(params[:user])
      flash[:success] = 'Preferences saved'
      redirect_to preferences_path
      log "edit_user success"
      return
    else
      flash[:error] = 'Failed to update.'
      log "edit_user fail #{@user.errors.full_messages.join('. ')}"
    end

    render :action => 'edit'
  end

  def search
    return access_denied unless current_user && current_user.teacher?

    query = params[:query]

    if query.include? '@'
      users = User.where(:email => query).order(:lastname).limit(100).all
    else
      users = User.where(["lower(firstname) LIKE ? OR lower(lastname) LIKE ?", "%#{query.downcase}%", "%#{query.downcase}%"]).order(:lastname).limit(100).all
    end

    respond_to do |format|
      format.json { render :json => users.as_json(:only => [ :id, :firstname, :lastname ]) }
    end
  end
end
