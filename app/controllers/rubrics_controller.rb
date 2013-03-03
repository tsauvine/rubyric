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
  end

  # PUT
  def update
    @exercise = Exercise.find(params[:exercise_id])
    load_course
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @exercise.rubric = params[:rubric]
    @exercise.save!

    respond_to do |format|
      format.json { head :no_content }
    end
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

    # file = params[:xml][:file] if params[:xml] && params[:xml][:file]

    # Check that a file is uploaded
    # FIXME: check Rails 3 compatibility
#     unless [ActionController::UploadedStringIO, ActionController::UploadedTempfile].include?(file.class) and file.size.nonzero?
#       return
#     end

    # Load xml
    if params[:file] && !params[:file].blank?
      #@exercise.load_json(params[:file])
      @exercise.rubric = params[:file].read
      @exercise.save
      redirect_to edit_exercise_rubric_path(@exercise)
    end
    
  end

  def download
    @exercise = Exercise.find(params[:id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    xml = @exercise.generate_xml
    send_data(xml, :filename => "#{@exercise.name}.xml", :type => 'text/xml')

    #redirect_to :controller => 'exercises', :action => 'show', :id => @exercise.id
    #redirect_to @exercise
  end
  
end
