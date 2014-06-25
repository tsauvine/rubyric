class PasswordResetsController < ApplicationController
  #before_filter :require_no_user
  before_filter :load_user_using_perishable_token, :only => [ :edit, :update ]

  def new
    @user_not_found = false
    @email = nil
    log "password_reset_order view"
  end

  def create
    @email = params[:email].strip
    if @email.blank?
      render :action => :new
      return
    end
    
    @user = User.find_by_email(@email) 
    
    if @user
      @user.deliver_password_reset_instructions
      flash[:success] = t('password_resets.password_reset_mailed')
      redirect_to root_path
      log "password_reset_order success #{@email}"
    else
      @user_not_found = true
      render :action => :new
      log "password_reset_order fail #{@email}"
    end
  end

  def edit
    log "password_reset view #{@user.id}"
  end

  def update
    if params[:password].blank?
      render :action => :edit
      return
    end
    
    @user.password = params[:password]
    #@user.password_confirmation = params[:password]

    if @user.save
      flash[:success] = t('password_resets.edit.success_message')
      Session.create(@user)
      redirect_to root_path
      log "password_reset success #{@user.id}"
    else
      render :action => :edit
      log "password_reset fail #{@user.id}"
    end
  end


  private

  def load_user_using_perishable_token
    @user = User.find_using_perishable_token(params[:id])
    unless @user
      flash[:error] = t('password_resets.invalid_link')
      redirect_to new_password_reset_path
      return false
    end
  end
end 
