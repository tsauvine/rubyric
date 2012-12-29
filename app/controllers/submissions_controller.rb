class SubmissionsController < ApplicationController
  before_filter :login_required, :only => [:show]

  layout 'wide'

  # Download submission
  def show
    @submission = Submission.find(params[:id])
    @exercise = @submission.exercise
    load_course

    # TODO: @submission.has_reviewer(current_user)
    return access_denied unless @submission.group.has_member?(current_user) || @course_instance.has_assistant(current_user) || @course.has_teacher(current_user) || is_admin?(current_user)

    # logger.info("mime type: #{Mime::Type.lookup_by_extension(@submission.extension)}")

    unless File.exist?(@submission.full_filename)
      # TODO: better error message
      @heading = 'File not found'
      render :template => "shared/error"
    else
      filename = @submission.filename || "#{@submission.id}.#{@submission.extension}"
      type = Mime::Type.lookup_by_extension(@submission.extension)

      send_file @submission.full_filename, :type => Mime::Type.lookup_by_extension(@submission.extension) || 'application/octet-stream', :filename => filename
    end
  end

  # Submit
  def new
    @exercise = Exercise.find(params[:exercise])
    load_course

    @user = current_user
    @is_teacher = @course.has_teacher(current_user)

    # Authorization
    return access_denied unless current_user || @exercise.submit_without_login

    # Check that instance is open
    unless @course_instance.active
      render :action => 'instance_inactive'
      return
    end

    # Find groups that the user is part of
    if @user
      @available_groups = Group.where('course_instance_id=? AND user_id=?', @course_instance.id, @user.id).joins(:users)
    else
      @available_groups = []
    end

    # Select group
    if params[:group]
      # Group given as a parameter
      @group = Group.find(params[:group])
      return access_denied unless @group.has_member?(current_user) || @is_teacher
    elsif @available_groups.size > 0
      @group = @available_groups[0]
    end

    # Redirect to create group if no group is selected
    if !@group && @exercise.groupsizemax > 1
      redirect_to new_exercise_group_path(:exercise_id => @exercise.id)
      return
    end

    @submission = Submission.new
  end

  def create
    @submission = Submission.new(params[:submission])
    @exercise = @submission.exercise
    load_course

    return access_denied unless logged_in? || @exercise.submit_without_login

    # Check that instance is open
    unless @course_instance.active
      flash[:error] = 'Submission rejected. Course instance is not active.'
      redirect_to submit_url(@exercise.id)
      return
    end


    user = current_user
    unless @submission.group
      if @exercise.groupsizemax <= 1 && current_user
        # Create a group automatically
        @group = Group.create({:course_instance_id => @course_instance.id, :name => user.studentnumber})
        @group.users << user

        # Add user to the course
        @course_instance.students << user unless @course_instance.students.include?(user)

        @submission.group = @group
      else
        flash[:error] = 'No group selected'
        redirect_to submit_path(:exercise => @submission.exercise_id)
        return
      end
    end

    # Check the file
    file = params[:file]

    if file.blank?
      flash[:error] = 'You must submit a file'
      redirect_to submit_url(@exercise.id)
      return
    else
      @submission.file = file
    end

    if @submission.save
      flash[:success] = 'Submission was received'
      redirect_to submit_path(:exercise => @submission.exercise_id)
    else
      flash[:error] = 'Failed to submit'
    end

    # Auto assign
#     if @exercise.autoassign
#       @submission.group.submissions.each do |submission|
#         # Take the first submission that has been assigned to somebody
#         old_review = submission.reviews.first
#         unless old_review.nil?
#           new_review = @submission.assign_to(old_review.user)
#           Mailer.deliver_assignment(new_review)
#           break
#         end
#       end
#     end
  end

  # Assign to current user and start review
  def review
    @submission = Submission.find(params[:id])
    @exercise = @submission.exercise
    load_course
    return access_denied unless @course.has_teacher(current_user)

    review = @submission.assign_to(current_user)

    redirect_to edit_review_path(review)
  end

end
