class ReviewsController < ApplicationController

  layout 'wide'

  # GET /reviews/1
  def show
    @review = Review.find(params[:id])
    @exercise = @review.submission.exercise
    load_course

    unless @review.user == current_user || @course.has_teacher(current_user) || is_admin?(current_user)
      @heading = 'Unauthorized'
      render :template => "shared/error"
    end
  end

  # GET /courses/1/edit
  def edit
    @review = Review.find(params[:id], :include => {:feedbacks => :item_grades})
    @exercise = @review.submission.exercise
    load_course

    # Authorization
    unless @review.user == current_user || @course.has_teacher(current_user) || is_admin?(current_user)
      @heading = 'Unauthorized'
      render :template => "shared/error"
      return
    end

    if params[:section]
      @section = Section.find(params[:section], :include => {:items => :phrases})
    else
      # Find the first section that exists
      # TODO: do more efficiently by SQL
      @exercise.categories.each do |category|
        @section = category.sections.first
        break if @section
      end
    end

    # Empty rubric
    unless @section
      # Go to finish
      @review.status = 'unfinished'
      @review.save
      redirect_to({:controller => 'reviews', :action => 'finish', :id => @review.id})
      return
    end
    
    @feedback = @review.find_feedback(@section.id)
  end

  def finish
    @review = Review.find(params[:id])
    @exercise = @review.submission.exercise
    load_course

    # Authorization
    return access_denied unless @review.user == current_user || @course.has_teacher(current_user) || is_admin?(current_user)

    # Check state
    if !['unfinished', 'finished', 'mailed'].include?(@review.status)
      redirect_to :action => 'edit'
      return
    end
    
    # Mail button
    @enable_mailing = @course.has_teacher(current_user) || (@review.user == current_user && @exercise.grader_can_email)

    # Collect feedback from sections and calculate grade
    if @review.status == 'unfinished'
      @review.collect_feedback
      @review.calculate_grade
    end
  end

  def update_finish
    @review = Review.find(params[:id])
    @exercise = @review.submission.exercise
    load_course

    # Authorization
    unless @review.user == current_user || @course.has_teacher(current_user) || is_admin?(current_user)
      @heading = 'Unauthorized'
      render :template => "shared/error"
      return
    end

    unless ['unfinished','finished'].include?(@review.status)
      flash[:error] = 'This review cannot be modified any more'
      render :action => 'finish'
      return
    end

    # Update status
    @review.calculate_grade

    if params[:mail]
      @review.status = 'mailed'
    else
      @review.status = 'finished'
    end

    unless @review.update_attributes(params[:review])
      # Error
      flash[:error] = 'Failed to update'
      render :action => 'finish'
      return
    end

    if params[:mail] && (@course.has_teacher(current_user) || (@review.user == current_user && @exercise.grader_can_email))
      # Mail immediately
      Mailer.deliver_review(@review)
    end

    redirect_to @exercise
  end

  def reopen
    @review = Review.find(params[:id])
    @exercise = @review.submission.exercise
    load_course

    # Authorization
    unless @course.has_teacher(current_user) || (@review.user == current_user && @exercise.grader_can_email) || is_admin?(current_user)
      @heading = 'Unauthorized'
      render :template => "shared/error"
      return
    end

    if @review.status == 'mailed'
      @review.status = 'finished'
      @review.save
    end

    redirect_to :action => 'finish', :id => @review.id
  end


  # PUT /reviews/1
  def update
    @review = Review.find(params[:id])
    @exercise = @review.submission.exercise
    @section = Section.find(params[:section]) unless params[:section].blank?
    @section ||= Section.new
    load_course

    # Authorization
    return access_denied unless @review.user == current_user || @course.has_teacher(current_user) || is_admin?(current_user)

    # Check that the review has not been mailed
    if @review.status == 'mailed'
      redirect_to({:controller => 'reviews', :action => 'edit', :id => params[:id], :section => params[:section]})
      return
    end

    # Update feedback
    if @section.new_record?
      # Special case of empty rubric
      @feedback = Feedback.find(:first, :conditions => ["review_id = ?", @review.id])
    else
      @feedback = Feedback.find(:first, :conditions => ["section_id = ? AND review_id = ?", @section.id, @review.id])
    end

    # Read item grading options from the hidden fields
    grades = Array.new
    grades_set = true

    @section.items.each do |item|
      next if item.item_grading_options.size < 1

      igo_id = params[:item_grades][item.id.to_s]
      begin
        grade = ItemGradingOption.find(igo_id)
        grades << grade
      rescue
        grades_set = false
      end
    end

    @feedback.item_grades = grades


    # Is this section finished?
    if grades_set && (!params[:feedback][:section_grading_option_id].blank? || @section.section_grading_options.size < 1)
      @feedback.status = 'finished'
    else
      @feedback.status = 'started'
    end

    # Save feedback
    unless @feedback.update_attributes(params[:feedback])
      # Error
      flash[:error] = 'Failed to update'
      render :action => "edit"
      return
    end

    # Are all sections finished?
    if @review.sections_finished?
      @review.status = 'unfinished'
    else
      @review.status = 'started'
    end

    @review.save

    # Redirect to the next section
    next_section = @section.next_sibling

    if !next_section && @section.category
      next_category = @section.category.next_sibling
      next_section = next_category.sections.first if next_category
    end

    if next_section
      redirect_to({:controller => 'reviews', :action => 'edit', :id => params[:id], :section => next_section})
    elsif @review.status == 'unfinished'
      redirect_to({:controller => 'reviews', :action => 'finish', :id => params[:id]})
    else
      flash[:warning] = 'Finish grading by selecting one grading option for each item and section'
      redirect_to({:controller => 'reviews', :action => 'edit', :id => params[:id], :section => params[:section]})
    end
  end

end
