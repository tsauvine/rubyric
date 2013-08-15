class CourseInstances::GroupsController < GroupsController
  before_filter :login_required

  layout 'application'
  
  def index
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course
    authorize! :update, @course_instance

    groups = @course_instance.groups.includes([:users, :reviewers])
    groups.each do |group|
      group.url = edit_course_instance_group_path(:course_instance_id => @course_instance.id, :id => group.id)
    end
    
    user_ids = groups.collect {|group| group.user_ids }
    user_ids << @course_instance.assistant_ids
    user_ids << @course.teacher_ids
    users = User.find(user_ids)
    
    response = { 
      groups: groups.as_json(:only => [:id], :methods => [:user_ids, :reviewer_ids, :url]),
      users: users.as_json(:only => [:id, :studentnumber, :email, :firstname, :lastname] ),
      assistants: @course_instance.assistant_ids,
      teachers: @course.teacher_ids
    }
    
    respond_to do |format|
      format.html { }
      format.json { render :json => response }
    end
  end
  
  def update
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course
    authorize! :update, @course_instance
    
    @course_instance.set_assignments(params[:assignments])
    
    respond_to do |format|
      format.html { redirect_to @course_instance }
      format.json { head :ok }
    end
  end

  def batch
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course
    authorize! :update, @course_instance
    
    if params[:paste]
      @course_instance.batch_create_groups(params[:paste])
      redirect_to course_instance_groups_path
    end
  end
  
end
