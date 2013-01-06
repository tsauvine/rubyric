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
