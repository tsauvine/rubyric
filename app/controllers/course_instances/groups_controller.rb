class CourseInstances::GroupsController < CourseInstancesController
  before_filter :login_required

  def index
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course

    groups = @course_instance.groups # .includes([:users])
    
    user_ids = groups.collect {|group| group.user_ids }
    user_ids << @course_instance.assistant_ids
    user_ids << @course.teacher_ids
    users = User.find(user_ids)
    
    response = { groups: groups.as_json(:only => [:id], :methods => [:user_ids]), users: users.as_json(:only => [:id, :studentnumber, :firstname, :lastname] ), assistants: @course_instance.assistant_ids, teachers: @course.teacher_ids }
    
    respond_to do |format|
      format.html { }
      format.json { render :json => response }
      # @groups.as_json(:only => [:id], :include => [{:users => {:only => [:studentnumber, :firstname, :lastname]}}])
    end
  end

end
