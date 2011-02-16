class FrontpageController < ApplicationController

  def index
    if current_user
      # course instances as assistant
      @course_instances = Array.new
      @course_instances.concat(current_user.course_instances_assistant)
      @course_instances.concat(current_user.course_instances_student)
      
      # course instances as teacher
      @courses = current_user.courses_teacher

      render :action => 'course_instances'
    else
      @session = Session.new
      render :action => 'info'
    end

  end

end
