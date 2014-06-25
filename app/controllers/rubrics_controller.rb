class RubricsController < ApplicationController

  layout 'wide'

  def show
    @exercise = Exercise.find(params[:exercise_id])
    load_course
    #return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    respond_to do |format|
      format.html { render text: @exercise.rubric }
      format.json { render json: @exercise.rubric }
    end
  end

  def edit
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
    
    log "edit_rubric #{@exercise.id}"
  end

  # PUT
  def update
    @exercise = Exercise.find(params[:exercise_id])
    load_course
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @exercise.rubric = params[:rubric]
    @exercise.save!

    respond_to do |format|
      format.json { render :json => { :status => 'ok' } }
    end
    
    log "update_rubric #{@exercise.id}"
  end

  def preview
    @review = Review.new
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @feedback = Feedback.new
  end


  def upload
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    # Load xml
    if params[:file] && !params[:file].blank?
      @exercise.load_rubric(params[:file].read)
      @exercise.save
      redirect_to edit_exercise_rubric_path(@exercise)
      log "rubric_upload success #{@exercise.id}"
    else
      log "rubric_upload view #{@exercise.id}"
    end
  end

  def download
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    #xml = @exercise.generate_xml
    #send_data(xml, :filename => "#{@exercise.name}.xml", :type => 'text/xml')
    json = @exercise.rubric
    send_data(json, :filename => "#{@exercise.name}.json", :type => 'application/json')
    
    log "rubric_download #{@exercise.id}"
  end
  
end
