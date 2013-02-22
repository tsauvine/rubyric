class GroupsController < ApplicationController
  before_filter :login_required, :only => [:index]

  layout 'wide'
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

    # TODO: redirect to the correct IdP if using shibboleth
    return access_denied unless logged_in? || @exercise.submit_without_login

    @group = Group.new

    # Prefill the form
    #@studentnumber = Array.new
    @email = Array.new

    @email_fields_count = @exercise.groupsizemax
    @email_fields_count -= 1 if logged_in?

#     if current_user
#       #@studentnumber[0] = current_user.studentnumber
#       @email[0] = current_user.email
#     end
  end

  # GET /groups/1/edit
  def edit
    @group = Group.find(params[:id])

    if params[:exercise_id]
      @exercise = Exercise.find(params[:exercise_id])
      load_course
    end
    
    return access_denied unless is_admin?(current_user) || @group.has_member?(current_user) || (@course && @course.has_teacher(current_user))
    
    @email_fields_count = @exercise.groupsizemax - @group.users.size - @group.group_invitations.size
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
        email.strip!
        invitation = GroupInvitation.find(id)
        if email.blank?
          logger.info "DELETIGN INVITATION #{invitation.email}"
          invitation.destroy
        elsif email != invitation.email
          invitation.email = email
          invitation.save
          
          if ENABLE_DELAYED_JOB
            InvitationMailer.delay.group_invitation(invitation.id)
          else
            InvitationMailer.group_invitation(invitation.id).deliver
          end
        end
      end
    end

    redirect_to submit_path(:exercise => @exercise.id, :group => @group.id)
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

  # DELETE /groups/1
  # DELETE /groups/1.xml
  def destroy
    return access_denied unless is_admin?(current_user)

    @group = Group.find(params[:id])
    @group.destroy
    redirect_to(groups_url)
  end

end
