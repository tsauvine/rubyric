class RubricsController < ApplicationController

  layout 'wide'

  def show
    @exercise = Exercise.find(params[:exercise_id])
    load_course
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

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


end
