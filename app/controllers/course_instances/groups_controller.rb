class CourseInstances::GroupsController < GroupsController
  before_filter :login_required

  layout 'application'
  
  def show
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course
    authorize! :update, @course_instance

    groups = @course_instance.groups.includes([:users, :reviewers])
    groups.each do |group|
      group.url = "/" # TODO
    end
    
    user_ids = groups.collect {|group| group.user_ids }
    user_ids << @course_instance.assistant_ids
    user_ids << @course.teacher_ids
    users = User.find(user_ids)
    
    response = { groups: groups.as_json(:only => [:id, :url], :methods => [:user_ids, :reviewer_ids]), users: users.as_json(:only => [:id, :studentnumber, :firstname, :lastname] ), assistants: @course_instance.assistant_ids, teachers: @course.teacher_ids }
    
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

end
