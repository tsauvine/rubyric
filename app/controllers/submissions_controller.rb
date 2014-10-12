class SubmissionsController < ApplicationController
  before_filter :load_submission, :except => [:new, :create]

  layout 'narrow'

  def load_submission
    @submission = Submission.find(params[:id])
    @exercise = @submission.exercise
    load_course
  end

  # Download submission
  def show
    return access_denied unless group_membership_validated(@submission.group) || @submission.has_reviewer?(current_user) || @course.has_teacher(current_user)
    
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
  
  
  # Submit
  def new
    if @course_instance.submission_policy == 'lti'
      # LTI
      return unless authorize_lti
      @exercise = Exercise.find_by_(params[:context_id])
      @user = nil   # todo later: remember LTI users
    else
      # Standalone
      @exercise = Exercise.find(params[:exercise])
      @user = current_user
    end
    
    load_course
    I18n.locale = @course_instance.locale || I18n.locale
    @is_teacher = @course.has_teacher(current_user)
    
    # Authorization
    # TODO: redirect to appropriate IdP
    return access_denied unless current_user || ['unauthenticated', 'lti'].include?(@course_instance.submission_policy)

    # Check that instance is active and student is enrolled
    return unless @is_teacher || submission_policy_accepted
    
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
    if params[:member_token]
      logger.debug "Memebr token given (#{params[:member_token]})"
      member = GroupMember.find_by_access_token(params[:member_token])
      if member
        @group = member.group
        logger.debug "Member found"
        
        unless member.user_id
          logger.debug "Member authenticated"
          member.authenticated()
          flash[:success] = t('submissions.new.email_confirmed')
        end

      else
        logger.debug "Member not found. Invalid token. Group not selected."
        render :action => 'invalid_token', :status => 403
        return
      end
    elsif params[:group_token]
      logger.debug "Group token given"
      @group = Group.find_by_access_token(params[:group_token])

      unless @group
        render :action => 'invalid_token', :status => 403
        return
      end
    elsif params[:group]
      @group = Group.find(params[:group])
      return access_denied unless @group.has_member?(current_user) || @is_teacher
    end
    
    # Autoselect group if exactly one is available
    if !@group && @available_groups.size == 1
      #user_count = @available_groups[0].users.size
      @group = @available_groups[0] if @exercise.groupsizemax == 1 && @available_groups[0].max_size == 1
    end
    
    # Unauthenticated users must always create group manually
    if !@group && @course_instance.submission_policy == 'unauthenticated'
      logger.debug "No group selected. Redirect to create group."
      redirect_to new_exercise_group_path(:exercise_id => @exercise.id)
      return
    end
    
    # Show group selection page if necessary
    if !@group && (@available_groups.size > 1 || @exercise.groupsizemax > 1 || @is_teacher)
      render :action => 'select_group'
      log "select_group #{@exercise.id}"
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
    
    # TODO: LTI params must be resubmitted by the submission form
  end

  def create
    if @course_instance.submission_policy == 'lti'
      # LTI
      return unless authorize_lti
      @user = nil   # todo later: remember LTI users
    else
      # Standalone
      @user = current_user
    end
    
    @submission = Submission.new(params[:submission])
    @exercise = @submission.exercise
    load_course
    I18n.locale = @course_instance.locale || I18n.locale
    @is_teacher = @course.has_teacher(@user)
    
    return access_denied unless logged_in? || ['unauthenticated', 'lti'].include?(@course_instance.submission_policy)
    logger.debug "Login accepted"

    # Check that instance is active and student is enrolled
    return unless @is_teacher || submission_policy_accepted
    logger.debug "Submission policy accepted"
    
    if @submission.group
      # Check that user is member of group
      unless group_membership_validated(@submission.group) || @is_teacher
        render :template => 'shared/forbidden', :status => 403, :layout => 'wide'
        return
      end
      logger.debug "Membership accepted"
    else
      logger.debug "No group specified"
      if @course_instance.submission_policy == 'lti' || (@exercise.groupsizemax <= 1 && current_user)
        logger.debug "Creating group of one"
        # Create a group automatically
        groupname = @user ? @user.studentnumber : 'untitled group' # FIXME: groupname in LTI
        group = Group.new({:course_instance_id => @course_instance.id, :exercise_id => @exercise.id, :name => groupname})
        group.save(:validate => false)
        group.add_member(@user) if @user  # FIXME: LTI user must be created

        @submission.group = group
      else
        flash[:error] = 'No group selected'
        redirect_to submit_path(:exercise => @submission.exercise_id)
        return
      end
    end
    logger.debug "Group accepted"

    # Check the file
    if params[:file].blank?
      logger.debug "No file submitted"
      flash[:error] = t('submissions.new.missing_file')
      redirect_to submit_url(@exercise.id, :member_token => params[:member_token], :group_token => params[:group_token])
      return
    else
      @submission.file = params[:file]
    end
    logger.debug "Submission accepted"

    if @submission.save
      flash[:success] = t('submissions.new.submission_received')
      log "submit success #{@submission.id},#{@exercise.id}"
    else
      flash[:error] = "Failed to submit. #{@submission.errors.full_messages.join('. ')}"
      log "submit fail #{@exercise.id} #{@submission.errors.full_messages.join('. ')}"
    end
    
    logger.debug "Submission successful"
    #if @course_instance.submission_policy == 'lti'
      redirect_to submit_path(:exercise => @submission.exercise_id, :group => @submission.group_id, :member_token => params[:member_token], :group_token => params[:group_token])
    #else
    #end
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
  
    
  private
  
  def submission_policy_accepted
    logger.debug "Checking submission policy"
    
    # Check that instance is open
    if !@course_instance.active
      render :action => 'instance_inactive'
      log "submit view #{@exercise.id} instance_inactive"
      logger.debug "Instance inactive"
      return false
    end
    
    # Check enrollment
    if @course_instance.submission_policy == 'enrolled' && !@course_instance.students.include?(@user)
      render :action => 'not_enrolled'
      log "submit view #{@exercise.id} not_enrolled"
      logger.debug "Not enrolled"
      return false
    end
    
    return true
  end
  
  def authorize_lti
    key = params['oauth_consumer_key']
    
    unless key
      @heading =  "No consumer key"
      render :template => "shared/error"
      return false
    end
    
    secret = OAUTH_CREDS[key]
    unless secret
      @tp = IMS::LTI::ToolProvider.new(nil, nil, params)
      @tp.lti_msg = "Your consumer didn't use a recognized key."
      @tp.lti_errorlog = "You did it wrong!"
      @heading =  "Consumer key wasn't recognized"
      render :template => "shared/error"
      return false
    end
    
    @tp = IMS::LTI::ToolProvider.new(key, secret, params)
    
    unless @tp.valid_request?(request)
      @heading =  "The OAuth signature was invalid"
      render :template => "shared/error"
      return false
    end
    
    if Time.now.utc.to_i - @tp.request_oauth_timestamp.to_i > 60*60
      @heading =  "Your request is too old."
      render :template => "shared/error"
      return false
    end
    
    if was_nonce_used_in_last_x_minutes?(@tp.request_oauth_nonce, 60)
      @heading =  "Why are you reusing the nonce?"
      render :template => "shared/error"
      return false
    end
    
    @username = @tp.username("Dude")
    return true
  end
  
  def was_nonce_used_in_last_x_minutes?(nonce, minutes=60)
    # some kind of caching solution or something to keep a short-term memory of used nonces
    false
  end
end
