class Courses::TeachersController < CoursesController
  before_filter :login_required

  def index
    @course = Course.find(params[:course_id])
    
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @invitations = TeacherInvitation.where(:target_id => @course.id).all
    #@allow_edit = @course.has_teacher(current_user) || is_admin?(current_user)
    log "teachers view #{@course.id}"
  end
  
  def create
    @course = Course.find(params[:course_id])

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    added_users = []
    invited_users = []
    
    # Add by user_id
    if params[:user_id]
      user_ids = params[:user_id].split(',').map {|u| u.strip.to_i}
      users_to_add = User.find(user_ids) - @course.teachers
      @course.teachers << users_to_add
      
      added_users.concat(users_to_add)
    end
    
    # Invite by email
    if params[:email]
      emails = params[:email].split(',')
      
      emails.each do |address|
        invitation = TeacherInvitation.create(:target_id => @course.id, :email => address.strip, :expires_at => Time.now + 1.weeks)
        InvitationMailer.delay.teacher_invitation(invitation.id)
        
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
    @course = Course.find(params[:course_id])

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
    
    # Don't remove the last user
    if @course.teachers.size < 2
      respond_to do |format|
        #format.html { redirect_to course_teachers_path(@course) }
        format.json {
          render :json => "Course must have at least one instructor.", :status => :bad_request
        }
      end
      
      return
    end
    
    user = User.find(params[:id])
    @course.teachers.delete user
    
    respond_to do |format|
      #format.html { redirect_to course_teachers_path(@course) }
      format.json { render :json => [user.id].as_json }
    end
  end
end
