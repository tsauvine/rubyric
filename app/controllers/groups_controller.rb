class GroupsController < ApplicationController
  before_filter :login_required, :only => [:index]

  layout 'narrow'
# 
#   def set_layout
#     case params[:embed]
#     when 'embed'
#       'embed'
#     else
#       'wide'
#     end
#   end

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
    @is_teacher = @course.has_teacher(current_user)

    # TODO: redirect to the correct IdP if using shibboleth
    return access_denied unless logged_in? || @exercise.submit_without_login

    @group = Group.new

    # Prefill the form
    #@studentnumber = Array.new
    @email = Array.new

    @email_fields_count = @exercise.groupsizemax
    
    if @is_teacher
      @email[0] = current_user.email
    else
      @email_fields_count -= 1 if logged_in?
    end
    
    log "create_group view #{@exercise.id}"
  end

  # GET /groups/1/edit
  def edit
    @group = Group.find(params[:id])

    if params[:exercise_id]
      @exercise = Exercise.find(params[:exercise_id])
      @email_fields_count = @exercise.groupsizemax - @group.users.size - @group.group_invitations.size
      log "edit_group view exercise #{@exercise.id}"
    elsif params[:course_instance_id]
      @course_instance = CourseInstance.find(params[:course_instance_id])
      @email_fields_count = 0
      log "edit_group view course_instance #{@exercise.id}"
    end
    load_course
    
    return access_denied unless is_admin?(current_user) || @group.has_member?(current_user) || (@course && @course.has_teacher(current_user))
  end

  # POST /groups
  def create
    @exercise = Exercise.find(params[:exercise_id])
    load_course
    @is_teacher = @course.has_teacher(current_user)
    
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
    @group.add_member(current_user) if current_user && !@is_teacher

    # Automatic groupname
    @group.name = (@group.users.collect { |user| user.studentnumber }).join('_')

    if @group.save
      @group.add_members_by_email(members, @exercise)
      redirect_to submit_path(:exercise => @exercise.id, :group => @group.id)
      
      log "create_group success #{@group.id},#{@exercise.id}"
    else
      flash[:error] = 'Failed to create group.'
      redirect_to :action => "new"
      log "create_group fail #{@exercise.id} #{@group.errors.full_messages.join('. ')}"
    end

  end

  def update
    @group = Group.find(params[:id])

    if params[:exercise_id]
      @exercise = Exercise.find(params[:exercise_id])
      load_course
    end
    
    return access_denied unless is_admin?(current_user) || @group.has_member?(current_user) || (@course && @course.has_teacher(current_user))
    
    # New members
    members = Array.new
    if params[:email]
      params[:email].each do |index, email|
        members << email unless email.empty?
      end
      
      @group.add_members_by_email(members, @exercise)
    end

    # Edit invitations
    if params[:invitations]
      params[:invitations].each do |id, email|
        invitation = GroupInvitation.find(id)
        email.strip!
        if email.blank?
          invitation.destroy
        elsif email != invitation.email
          invitation.update_email(email)
        end
      end
    end

    redirect_to submit_path(:exercise => @exercise.id, :group => @group.id)
    log "edit_group success #{@group.id},#{@exercise.id}"
  end
  
  def join
    return access_denied unless logged_in?

    invitation = GroupInvitation.where(:group_id => params[:id], :token => params[:token]).first

    if invitation
      group = invitation.group
      exercise = invitation.exercise

      # Add user to group
      group.add_member(current_user)

      # Delete invitation
      invitation.destroy

      # Redirect to submit
      flash[:success] = 'You have been added to the group'
      redirect_to submit_path(:exercise => exercise.id, :group => group.id)
      log "join_group success #{group.id},#{exercise.id}"
    else
      render :invalid_token
      log "join_group fail invalid token"
    end

  end

  # DELETE /groups/1
  # DELETE /groups/1.xml
  def destroy
    return access_denied unless is_admin?(current_user)

    @group = Group.find(params[:id])
    @group.destroy
    redirect_to(groups_url)
  end

end
