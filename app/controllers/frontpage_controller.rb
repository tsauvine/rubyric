class FrontpageController < ApplicationController

  def show
    if current_user
      @courses_teacher = current_user.courses_teacher
      @instances_assistant = current_user.course_instances_assistant
      @instances_student = current_user.course_instances_student

      render :action => 'course_instances'
    else
      @session = Session.new
      render :action => 'info', :layout => 'narrow'
    end

    log "frontpage"
  end

end
