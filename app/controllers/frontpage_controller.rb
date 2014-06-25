class FrontpageController < ApplicationController

  def show
    if current_user
      @courses_teacher = current_user.courses_teacher
      @instances_assistant = current_user.course_instances_assistant
      @instances_student = current_user.course_instances_student

      render :action => 'course_instances', :layout => 'narrow-new'
      log "dashboard"
    else
      @session = Session.new
      @user = User.new
      render :action => 'info', :layout => 'frontpage'
      log "frontpage"
    end

  end

end
