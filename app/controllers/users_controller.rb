class UsersController < ApplicationController
  # Be sure to include AuthenticationSystem in Application Controller instead
  include AuthenticatedSystem


  # GET /users/1
  def show
    @user = User.find(params[:id])

    unless is_admin?(current_user) || @user == current_user
      @heading = 'Unauthorized'
      render :template => "shared/error"
    end
  end

  # render new.rhtml
  def new
    unless is_admin?(current_user)
      @heading = 'Unauthorized'
      render :template => "shared/error"
      return
    end
  end

  def create
    unless is_admin?(current_user)
      @heading = 'Unauthorized'
      render :template => "shared/error"
      return
    end

    @user = User.new(params[:user])
    @user.save

    if @user.errors.empty?
      flash[:success] = "User #{@user.studentnumber} was successfully created."
    else
      flash[:error] = 'Failed to create.'
    end

    render :action => 'new'
  end


  def edit
    @user = User.find(params[:id])

    unless is_admin?(current_user) || @user == current_user
      @heading = 'Unauthorized'
      render :template => "shared/error"
    end
  end

  def update
    @user = User.find(params[:id])

    unless is_admin?(current_user) || @user == current_user
      @heading = 'Unauthorized'
      render :template => "shared/error"
      return
    end

    if @user.update_attributes(params[:user])
      flash[:success] = "User #{@user.studentnumber} was successfully updated."
    else
      flash[:error] = 'Failed to update.'
    end

    render :action => 'edit'
  end

end
