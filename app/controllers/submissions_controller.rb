class SubmissionsController < ApplicationController
  before_filter :login_required, :only => [:show]
  before_filter :load_submission, :except => [:new, :create]

  layout 'narrow'

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
          log "download_submission #{@submission.id},#{@exercise.id}"
        end
      end
      
      format.png do
        response.headers["Expires"] = 1.year.from_now.httpdate
        bitmap_info = @submission.image_path(params[:page], params[:zoom])
        send_file bitmap_info[:path], :filename => bitmap_info[:filename], :type => bitmap_info[:mimetype], :disposition => 'inline'
      end
    end
  end

  
  
  def new
    @exercise = Exercise.find(params[:exercise])
    load_course

    @user = current_user
    @is_teacher = @course.has_teacher(current_user)
    
    # Authorization
    return access_denied unless current_user || @course_instance.submission_policy == 'unauthenticated'

    # Check that instance is open
    if !@course_instance.active && !@is_teacher
      render :action => 'instance_inactive'
      log "submit view #{@exercise.id} instance_inactive"
      return
    end

    # TODO: Check enrollment
    
    # Select group
    @group = nil
    if params[:group]
      # TODO: add some auth token
      @group = Group.find(params[:group])
      
      # TODO: authenticate
      # user is member of group || user knows key
    end
    
    
    
    
  end
  
  
  # Submit
  def new
    @exercise = Exercise.find(params[:exercise])
    load_course

    @user = current_user
    @is_teacher = @course.has_teacher(current_user)
    
    # Authorization
    return access_denied unless current_user || @course_instance.submission_policy == 'unauthenticated'

    # Check that instance is open
    if !@course_instance.active && !@is_teacher
      render :action => 'instance_inactive'
      log "submit view #{@exercise.id} instance_inactive"
      return
    end
    
    # Check enrollment
    if @course_instance.submission_policy == 'enrolled' && !@course_instance.students.include?(@user)
      render :action => 'not_enrolled'
      log "submit view #{@exercise.id} not_enrolled"
      return
    end

    # Find groups that the user is part of
    if @is_teacher
      @available_groups = Group.where('course_instance_id=?', @course_instance.id).includes(:users).order(:name)
    elsif @user
      @available_groups = Group.where('course_instance_id=? AND user_id=?', @course_instance.id, @user.id).joins(:users).order(:name).all.select { |group| group.users.size <= @exercise.groupsizemax }
    else
      @available_groups = []
    end

    # Select group
    @group = nil
    if params[:group]
      @group = Group.find(params[:group])
      
      # TODO: Check that user is member or knows key
      
      return access_denied unless @group.has_member?(current_user) || @is_teacher || @course_instance.submission_policy == 'unauthenticated'
    end
    
    # Autoselect group if exactly one is available
    if !@group && @available_groups.size == 1
      user_count = @available_groups[0].users.size
      @group = @available_groups[0] if @exercise.groupsizemax == 1 && user_count == 1
    end
    
    # Show group selection page if necessary
    if !@group && (@available_groups.size > 1 || @exercise.groupsizemax > 1 || @is_teacher)
      render :action => 'select_group'
      log "select_group #{@exercise.id}"
      return
    end
    
    # Unauthenticated users must always create group manually
    if !@group && @course_instance.submission_policy == 'unauthenticated'
      redirect_to new_exercise_group_path(:exercise_id => @exercise.id)
      return
    end
    
    # Load previous submissions
    if @group
      @submissions = Submission.where(:group_id => @group.id, :exercise_id => @exercise.id).order('created_at DESC').all
    else
      @submissions = []
    end

    @submission = Submission.new
    log "submit view #{@exercise.id}"
  end

  def create
    @submission = Submission.new(params[:submission])
    @exercise = @submission.exercise
    load_course
    @is_teacher = @course.has_teacher(current_user)
    user = current_user
    
    return access_denied unless logged_in? || @course_instance.submission_policy == 'unauthenticated'

    # Check that instance is open
    unless @course_instance.active || @is_teacher
      flash[:error] = 'Submission rejected. Course instance is not active.'
      redirect_to submit_url(@exercise.id)
      return
    end
    
    # Check submisison policy
    if @course_instance.submission_policy == 'enrolled' && !@course_instance.students.include?(user)
      render :action => 'not_enrolled'
      return
    end

    unless @submission.group
      if @exercise.groupsizemax <= 1 && current_user
        # Create a group automatically
        @group = Group.create({:course_instance_id => @course_instance.id, :name => user.studentnumber})
        @group.add_member(user)

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
      redirect_to submit_path(:exercise => @submission.exercise_id, :group => @submission.group_id)
      log "submit success #{@submission.id},#{@exercise.id}"
    else
      flash[:error] = 'Failed to submit'
      log "submit fail #{@exercise.id} #{@submission.errors.full_messages.join('. ')}"
    end
  end

  # Assign to current user and start review
  def review
    return access_denied unless @course.has_teacher(current_user) || @submission.group.has_reviewer?(current_user)

    review = @submission.assign_to(current_user)

    redirect_to edit_review_path(review)
    log "create_review #{@submission.id},#{@exercise.id}"
  end

  def move
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
    
    if params[:target]
      target = Exercise.find(params[:target])
      @submission.move(target)
      
      redirect_to @exercise
      log "move_submission success #{@submission.id},#{@exercise.id}"
      return
    else
      log "move_submission view #{@submission.id},#{@exercise.id}"
    end
  end
  
  def confirm_delete
    return access_denied unless @submission.group.has_member?(current_user) || @course.has_teacher(current_user) || is_admin?(current_user)
    log "delete_submission view #{@submission.id},#{@exercise.id}"
  end
    
  # DELETE /submissions/1
  def destroy
    return access_denied unless @submission.group.has_member?(current_user) || @course.has_teacher(current_user) || is_admin?(current_user)
    return access_denied unless @submission.reviews.empty?

    log "delete_submission success #{@submission.id},#{@exercise.id}"
    @submission.destroy

    redirect_to @exercise
  end
end
