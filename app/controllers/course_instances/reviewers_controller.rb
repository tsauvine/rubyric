class CourseInstances::ReviewersController < CourseInstancesController
  before_filter :login_required

  def index
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course

    @invitations = AssistantInvitation.where(:target_id => @course_instance.id).all
  end

  def create
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    added_users = []
    invited_users = []
    
    # Add by user_id
    if params[:user_id]
      user_ids = params[:user_id].split(',').map {|u| u.strip.to_i}
      users_to_add = User.find(user_ids) - @course_instance.assistants
      @course_instance.assistants << users_to_add
      
      added_users.concat(users_to_add)
    end
    
    # Invite by email
    if params[:email]
      emails = params[:email].split(',')
      
      emails.each do |address|
        invitation = AssistantInvitation.create(:target_id => @course_instance.id, :email => address.strip, :expires_at => Time.now + 1.weeks)
        InvitationMailer.delay.assistant_invitation(invitation.id)
        
        invited_users << {id: invitation.id, email: address}
      end
    end
    
    response = { added_users: added_users.as_json(:only => [ :id, :firstname, :lastname, :email ]), invited_users: invited_users }
    
    respond_to do |format|
      #format.html { redirect_to course_teachers_path(@course) }
      format.json { render :json => response }
    end
  end
  
  def destroy
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
    
    user = User.find(params[:id])
    @course_instance.assistants.delete user
    
    respond_to do |format|
      #format.html { redirect_to course_teachers_path(@course) }
      format.json { render :json => [user.id].as_json }
    end
  end
end
