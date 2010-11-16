class UsersController < ApplicationController

  # GET /users/1
#   def show
#     @user = User.find(params[:id])
# 
#     return access_denied unless is_admin?(current_user) || @user == current_user
#   end

  def new
    return access_denied unless is_admin?(current_user)
  end

  def create
    return access_denied unless is_admin?(current_user)

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

    return access_denied unless is_admin?(current_user) || @user == current_user
  end

  def update
    @user = User.find(params[:id])

    return access_denied unless is_admin?(current_user) || @user == current_user

    if @user.update_attributes(params[:user])
      flash[:success] = "User #{@user.studentnumber} was successfully updated."
    else
      flash[:error] = 'Failed to update.'
    end

    render :action => 'edit'
  end

end
