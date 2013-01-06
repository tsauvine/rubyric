class CourseInstances::GroupsController < CourseInstancesController
  before_filter :login_required

  def index
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course

    @groups = @course_instance.groups
  end

end
