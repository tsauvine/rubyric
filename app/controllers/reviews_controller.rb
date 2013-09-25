class ReviewsController < ApplicationController

  # GET /reviews/1
  def show
    @review = Review.find(params[:id])
    @grader = @review.user
    @submission = @review.submission
    @group = @submission.group
    @exercise = @submission.exercise
    load_course

    return access_denied unless @group.has_member?(current_user) || @review.user == current_user || @course.has_teacher(current_user) || @course_instance.has_assistant(current_user) || is_admin?(current_user)
    
    respond_to do |format|
      format.html { render :action => 'show', :layout => 'narrow' }
      format.json { render json: @review.payload }
    end
  end

  # GET /reviews/1/edit
  def edit
    @review = Review.find(params[:id])
    @exercise = @review.submission.exercise
    load_course

    # Authorization
    return access_denied unless @review.user == current_user || @course.has_teacher(current_user) || is_admin?(current_user)

    render :action => 'edit', :layout => 'review'
  end

  # PUT /reviews/1
  def update
    @review = Review.find(params[:id])
    @exercise = @review.submission.exercise
    load_course

    # Authorization
    return access_denied unless @review.user == current_user || @course.has_teacher(current_user) || is_admin?(current_user)

    # Check that the review has not been mailed
    if @review.status == 'mailed'
      respond_to do |format|
        format.json { head :no_content } # TODO: error message
        format.html {
          flash[:error] = 'Review has already been mailed and cannot be edited any more'
          redirect_to @exercise
        }
      end

      return
    end

    if @review.update_attributes(params[:review])
      respond_to do |format|
        format.json { head :no_content } # TODO: ok
        format.html {
          redirect_to @exercise
        }
      end
    else
      respond_to do |format|
        format.json { head :no_content } # TODO: error message
        format.html {
          flash[:error] = 'Failed to update review'
          redirect_to @exercise
        }
      end
    end
    
#     respond_to do |format|
#       format.json { render :text => '{"status": "ok"}' }
#     end
  end

  def finish
    @review = Review.find(params[:id])
    @exercise = @review.submission.exercise
    load_course

    # Authorization
    return access_denied unless @review.user == current_user || @course.has_teacher(current_user) || is_admin?(current_user)

    # Check state
    if !['unfinished', 'finished', 'mailed'].include?(@review.status)
      # TODO
      #redirect_to :action => 'edit'
      #return
    end

    # Mail button
    @enable_mailing = @course.has_teacher(current_user) || (@review.user == current_user && @exercise.grader_can_email)

    @grade_options = []
    grades = @exercise.rubric_content()['grades']
    if grades && grades.size() > 0
      @grade_options << ''
      grades.each do |grade|
        @grade_options << grade
      end
    end
    
    # Collect feedback from sections and calculate grade
    #if @review.status == 'unfinished'
      #@review.collect_feedback
      #@review.calculate_grade
    #end


    render :action => 'finish', :layout => 'wide'
  end

  def update_finish
    @review = Review.find(params[:id])
    @exercise = @review.submission.exercise
    load_course

    # Authorization
    return access_denied unless @review.user == current_user || @course.has_teacher(current_user) || is_admin?(current_user)

#     unless ['unfinished','finished'].include?(@review.status)
#       flash[:error] = 'This review cannot be modified any more'
#       render :action => 'finish', :layout => 'wide'
#       return
#     end


#     if params[:mail]
#       @review.status = 'mailed'
#     else
      @review.status = 'finished'
#     end

    unless @review.update_attributes(params[:review])
      # Error
      flash[:error] = 'Failed to update'
      render :action => 'finish', :layout => 'wide'
      return
    end

   if params[:mail] && (@course.has_teacher(current_user) || (@review.user == current_user && @exercise.grader_can_email))
     # Mail immediately
     Review.deliver_reviews(@review.id)
   end

    redirect_to @exercise
  end

  def reopen
    @review = Review.find(params[:id])
    @exercise = @review.submission.exercise
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || (@review.user == current_user && @exercise.grader_can_email) || is_admin?(current_user)

    if @review.status == 'mailed'
      @review.status = 'finished'
      @review.save
    end

    redirect_to edit_review_path(@review)
  end

  def upload
    @review = Review.find(params[:id])
    @exercise = @review.submission.exercise
    load_course

    # Authorization
    return access_denied unless @review.user == current_user || @course.has_teacher(current_user) || is_admin?(current_user)

    # Load file
    if params[:file] && !params[:file].blank?
      @review.write_file(params[:file], @exercise)
      @review.save
      redirect_to edit_review_path(@review)
      return
    end
    
    render :action => 'upload', :layout => 'narrow'
  end
  
  # Download feedback file
  def download
    @review = Review.find(params[:id])
    @grader = @review.user
    @submission = @review.submission
    @group = @submission.group
    @exercise = @submission.exercise
    load_course

    return access_denied unless @group.has_member?(current_user) || @review.user == current_user || @course.has_teacher(current_user) || @course_instance.has_assistant(current_user) || is_admin?(current_user)
    
    respond_to do |format|
      format.html do
        if @review.filename.blank? || !File.exist?(@review.full_filename)
          # TODO: better error message
          @heading = 'File not found'
          render :template => "shared/error", :layout => 'narrow'
        else
          send_file @review.full_filename, :type => Mime::Type.lookup_by_extension(@review.extension) || 'application/octet-stream', :filename => @review.filename
        end
      end
    end
  end
  
  def annotation
    @review = Review.find(params[:id])
    @submission = @review.submission
    @exercise = @submission.exercise
    load_course
    
    return access_denied unless @review.user == current_user || @course.has_teacher(current_user) || is_admin?(current_user)
    
    @page_count = @submission.page_count
    
    render :action => 'annotation', :layout => 'annotation'
  end

end
