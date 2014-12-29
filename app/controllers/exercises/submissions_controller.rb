require 'batch_uploader.rb'

class Exercises::SubmissionsController < ExercisesController

  layout 'narrow-new'

  before_filter :authorize
  
  def authorize
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
  end
  
  def batch_upload
    if params[:file] && !params[:file].blank?
      batch_uploader = BatchUploader.new(@exercise.course_instance)
      failed_groups = batch_uploader.upload_submissions(@exercise, params[:file])
      
      #redirect_to exercise_path(@exercise)
      log "submission_batch_upload success #{@exercise.id}"
    else
      log "submission_batch_upload view #{@exercise.id}"
    end
  end

end
