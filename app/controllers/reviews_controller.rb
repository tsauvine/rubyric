class ReviewsController < ApplicationController

  #layout 'review'
  #layout 'wide', :only => ['finish']

  # GET /reviews/1
  def show
    @review = Review.find(params[:id])
    @grader = @review.user
    @submission = @review.submission
    @group = @submission.group
    @exercise = @submission.exercise
    load_course

    return access_denied unless @group.has_member?(current_user) || @review.user == current_user || @course.has_teacher(current_user) || is_admin?(current_user)
    
    respond_to do |format|
      format.html { render :action => 'show', :layout => 'wide' }
      format.json { render json: @review.payload }
    end
  end

  # GET /courses/1/edit
  def edit
    @review = Review.find(params[:id])
    @exercise = @review.submission.exercise
    load_course

    # Authorization
    return access_denied unless @review.user == current_user || @course.has_teacher(current_user) || is_admin?(current_user)

    #@feedback = @review.find_feedback(@section.id) if @section
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
#     if @review.status == 'mailed'
#       respond_to do |format|
#         format.json { head :no_content } # TODO: error message
#         #redirect_to({:controller => 'reviews', :action => 'edit', :id => params[:id], :section => params[:section]})
#       end
#
#       return
#     end

    @review.payload = params[:review]
    @review.collect_feedback
    @review.status = 'finished'
    @review.save!

    respond_to do |format|
      format.json { render :text => '{"status": "ok"}' }
    end

#     if next_section
#       redirect_to({:controller => 'reviews', :action => 'edit', :id => params[:id], :section => next_section})
#     elsif @review.status == 'unfinished'
#       redirect_to({:controller => 'reviews', :action => 'finish', :id => params[:id]})
#     else
#       flash[:warning] = 'Finish grading by selecting one grading option for each item and section'
#       redirect_to({:controller => 'reviews', :action => 'edit', :id => params[:id], :section => params[:section]})
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

    # Collect feedback from sections and calculate grade
    if @review.status == 'unfinished'
      #@review.collect_feedback
      #@review.calculate_grade
    end


    render :action => 'finish', :layout => 'wide'
  end

  def update_finish
    @review = Review.find(params[:id])
    @exercise = @review.submission.exercise
    load_course

    # Authorization
    return access_denied unless @review.user == current_user || @course.has_teacher(current_user) || is_admin?(current_user)

    unless ['unfinished','finished'].include?(@review.status)
      flash[:error] = 'This review cannot be modified any more'
      render :action => 'finish', :layout => 'wide'
      return
    end

    # Update status
    #@review.calculate_grade

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
     FeedbackMailer.review(@review).deliver
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

    redirect_to finish_review_path(@review)
  end

end
