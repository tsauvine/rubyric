class CourseInstances::GroupsController < CourseInstancesController
  before_filter :login_required

  def index
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course

    @groups = @course_instance.groups.includes([:users])
    
    respond_to do |format|
      format.html { }
      format.json { render :json => @groups.as_json(:only => [:id], :include => [{:users => {:only => [:studentnumber, :firstname, :lastname]}}]) }
    end
  end

end
