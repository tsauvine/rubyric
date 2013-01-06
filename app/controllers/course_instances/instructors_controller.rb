class CourseInstances::InstructorsController < CourseInstancesController
  before_filter :login_required

  def show
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course

    @invitations = TeacherInvitation.where(:target_id => @course.id).all
  end
end
