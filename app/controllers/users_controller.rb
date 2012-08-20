# RAILS 3
class UsersController < ApplicationController

  # GET /users/1
#   def show
#     @user = User.find(params[:id])
#
#     return access_denied unless is_admin?(current_user) || @user == current_user
#   end

  def new
    #return access_denied unless is_admin?(current_user)
    # Anyone can create an account
    @user = User.new
  end

  def create
    # Create user
    @user = User.new(params[:user])
    @user.save

    if @user.errors.empty?
      # Success
      logger.info("Created user #{@user.email} (traditional)")

      # Login
      #self.current_user = @user
      Session.create(@user)

      # Create course
      exercise = Course.create_example(@user)

      redirect_to exercise
    else
      # Form not sufficiently filled
      render :action => 'new'
    end
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
