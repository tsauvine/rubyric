class SubmissionsController < ApplicationController
  before_filter :login_required, :only => [:show]
  before_filter :load_submission, :except => [:new]

  layout 'wide'

  def load_submission
    @submission = Submission.find(params[:id])
    @exercise = @submission.exercise
    load_course
  end

  # Download submission
  def show
    # TODO: @submission.has_reviewer(current_user)
    return access_denied unless @submission.group.has_member?(current_user) || @course_instance.has_assistant(current_user) || @course.has_teacher(current_user) || is_admin?(current_user)

    # logger.info("mime type: #{Mime::Type.lookup_by_extension(@submission.extension)}")
    filename = @submission.filename || "#{@submission.id}.#{@submission.extension}"
    type = Mime::Type.lookup_by_extension(@submission.extension)
    
    respond_to do |format|
      format.html do
        unless File.exist?(@submission.full_filename)
          # TODO: better error message
          @heading = 'File not found'
          render :template => "shared/error"
        else
          send_file @submission.full_filename, :type => Mime::Type.lookup_by_extension(@submission.extension) || 'application/octet-stream', :filename => filename
        end
      end
        
      format.png do
        send_file @submission.png_path(params[:page], params[:zoom]), :type => 'image/png', :filename => "#{@submission.id}.png", :disposition => 'inline'
      end
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
    elsif @available_groups.size == 1
      @group = @available_groups[0]
    elsif @exercise.groupsizemax > 1 && @available_groups.size != 1
      render :action => 'select_group'
      return 
    end

    # Redirect to create group if no group is selected
    if !@group && @exercise.groupsizemax > 1
      redirect_to new_exercise_group_path(:exercise_id => @exercise.id)
      return
    end
    
    @submissions = Submission.where(:group_id => @group.id, :exercise_id => @exercise.id).order('created_at DESC').all

    @submission = Submission.new
  end

  def create
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
  end

  # Assign to current user and start review
  def review
    return access_denied unless @course.has_teacher(current_user) || @submission.group.has_reviewer?(current_user)

    review = @submission.assign_to(current_user)

    redirect_to edit_review_path(review)
  end

  def move
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
    
    if params[:target]
      target = Exercise.find(params[:target])
      @submission.move(target)
      
      redirect_to @exercise
    end
  end
  
  def confirm_delete
    return access_denied unless @submission.group.has_member?(current_user) || @course.has_teacher(current_user) || is_admin?(current_user)
  end
    
  # DELETE /submissions/1
  def destroy
    return access_denied unless @submission.group.has_member?(current_user) || @course.has_teacher(current_user) || is_admin?(current_user)
    return access_denied unless @submission.reviews.empty?

    @submission.destroy

    redirect_to @exercise
  end
  
end
