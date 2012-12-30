class GroupsController < ApplicationController
  before_filter :login_required, :only => [:index]

  layout 'wide'

  # GET /groups
  def index
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    if @course.has_teacher(current_user)
      @groups = Group.find_by_course_instance(@course_instance.id).joins(:users)
    else
      @groups = Group.where('course_instance_id=? AND user_id=?', @course_instance.id, current_user.id).joins(:users)
    end
  end

  # GET /groups/1
  # GET /groups/1.xml
#   def show
#     @group = Group.find(params[:id])
#   end

  def new
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    # TODO: redirect to the correct IdP
    return access_denied unless logged_in? || @exercise.submit_without_login

    @group = Group.new

    # Prefill the form
    #@studentnumber = Array.new
    @email = Array.new

    @email_fields_count = @course_instance.groupsizemax
    @email_fields_count -= 1 if logged_in?

#     if current_user
#       #@studentnumber[0] = current_user.studentnumber
#       @email[0] = current_user.email
#     end
  end

  # GET /groups/1/edit
  def edit
    @group = Group.find(params[:id])

    return access_denied unless is_admin?(current_user) || @group.has_member?(current_user)
  end

  # POST /groups
  def create
    @exercise = Exercise.find(params[:exercise_id])

    return access_denied unless logged_in? || @exercise.submit_without_login

    # Read addresses
    members = Array.new
    if params[:email]
      params[:email].each do |index, address|
        members << address unless address.empty?
      end
    end

#     if members.size < @exercise.groupsizemin
#       flash[:error] = "There must be at least #{@exercise.groupsizemin} member#{@exercise.groupsizemin == 1 ? '' : 's'} in the group."
#       redirect_to :action => "new", :exercise => params[:exercise]
#       return
#     end

    @group = Group.new(params[:group])
    @group.users << current_user if current_user

    # Automatic groupname
    @group.name = (@group.users.collect { |user| user.studentnumber }).join('_')

    if @group.save
      @group.add_members_by_email(members, @exercise)
      redirect_to submit_path(:exercise => @exercise.id, :group => @group.id)
    else
      flash[:error] = 'Failed to create group.'
      redirect_to :action => "new"
    end

  end

  def join
    return access_denied unless logged_in?

    invitation = GroupInvitation.where(:group_id => params[:id], :token => params[:token]).first

    if invitation
      group = invitation.group
      exercise = invitation.exercise

      # Add user to group
      group.users << current_user unless group.users.include?(current_user)

      # Delete invitation
      invitation.destroy

      # Redirect to submit
      flash[:success] = 'You have been added to the group'
      redirect_to submit_path(:exercise => exercise.id, :group => group.id)
    else
      render :invalid_token
    end

  end

  # PUT /groups/1
  # PUT /groups/1.xml
#   def update
#     @group = Group.find(params[:id])
#
#     respond_to do |format|
#       if @group.update_attributes(params[:group])
#         flash[:notice] = 'Group was successfully updated.'
#         format.html { redirect_to(@group) }
#         format.xml  { head :ok }
#       else
#         format.html { render :action => "edit" }
#         format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
#       end
#     end
#   end

  # DELETE /groups/1
  # DELETE /groups/1.xml
  def destroy
    unless logged_in?
      redirect_to_login
      return
    end

    return access_denied unless is_admin?(current_user)

    @group = Group.find(params[:id])
    @group.destroy
    redirect_to(groups_url)
  end

  # Ajax studentnumber checker
  def check_studentnumber
    user = User.find_by_studentnumber(params[:studentnumber])

    if !params[:studentnumber].empty? && !user
      render(:update) do |page|
        page.replace_html 'helpBox', "Student #{params[:studentnumber]} is not registered. Make sure you didn't misspell."
        page.select('#helpBox').first.show
      end
    else
      render(:update) do |page|
        page.select('#helpBox').first.hide
      end
    end
  end

  # Ajax email checker
  def check_email
    logger.info("Studentnumber: #{params[:studentnumber]}, Email: #{params[:email]}")

    user = User.find_by_studentnumber(params[:studentnumber])

    if user && !params[:email].empty? && user.email != params[:email]
      render(:update) do |page|
        page.replace_html 'helpBox', "Email address of student #{params[:studentnumber]} does not match the one in our database. Please check that you didn't misspell."
        page.select('#helpBox').first.show
      end
    else
      render(:update) do |page|
        page.select('#helpBox').first.hide
      end
    end
  end
end
