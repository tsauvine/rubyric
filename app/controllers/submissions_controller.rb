class SubmissionsController < ApplicationController
  before_filter :load_submission, except: [:new, :create, :aplus_get, :aplus_submit, :receive_email]

  layout 'narrow'

  def load_submission
    @submission = Submission.find(params[:id])
    @exercise = @submission.exercise
    load_course
  end

  # Download submission
  def show
    return access_denied unless group_membership_validated(@submission.group) || @submission.has_reviewer?(current_user) || @course.has_teacher(current_user) || (@exercise.collaborative_mode != '' && @course_instance.has_student(current_user))

    # logger.info("mime type: #{Mime::Type.lookup_by_extension(@submission.extension)}")
    filename = @submission.filename || "#{@submission.id}.#{@submission.extension}"

    respond_to do |format|
      format.html do
        unless File.exist?(@submission.full_filename)
          # TODO: better error message
          @heading = 'File not found'
          render template: 'shared/error'
        else
          mime_type = nil
          mime_type = Mime::Type.lookup_by_extension(@submission.extension.downcase) unless @submission.extension.blank?
          mime_type ||= 'application/octet-stream'

          send_file @submission.full_filename, type: mime_type, filename: filename
          log "download_submission #{@submission.id},#{@exercise.id}"
        end
      end

      format.png do
        response.headers['Expires'] = 1.year.from_now.httpdate
        bitmap_info = @submission.image_path(params[:page], params[:zoom])
        send_file bitmap_info[:path], filename: bitmap_info[:filename], type: bitmap_info[:mimetype], disposition: 'inline'
      end
    end
  end

  def thumbnail
    return access_denied unless group_membership_validated(@submission.group) || @submission.has_reviewer?(current_user) || @course.has_teacher(current_user) || (@exercise.collaborative_mode != '' && @course_instance.has_student(current_user))

    response.headers['Expires'] = 1.year.from_now.httpdate
    if File.exists? @submission.thumbnail_path
      send_file @submission.thumbnail_path, filename: "#{@submission.id}-thumbnail.jpg", type: 'image/jpeg', disposition: 'inline'
    else
      raise ActiveRecord::RecordNotFound
    end
  end


  # Submit
  def new
    @user = current_user
    @exercise = Exercise.find(params[:exercise])
    load_course
    I18n.locale = @course_instance.locale || I18n.locale
    @is_teacher = @course.has_teacher(current_user)

    # Authorization
    # TODO: redirect to appropriate IdP
    return access_denied unless current_user || @course_instance.submission_policy == 'unauthenticated'

    # Check that instance is active and student is enrolled
    return unless @is_teacher || submission_policy_accepted?

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
      logger.debug "Member token given (#{params[:member_token]})"
      member = GroupMember.find_by_access_token(params[:member_token])
      if member
        @group = member.group
        logger.debug 'Member found'

        unless member.user_id
          logger.debug 'Member authenticated'
          member.authenticated()
          flash[:success] = t('submissions.new.email_confirmed')
        end

      else
        logger.debug 'Member not found. Invalid token. Group not selected.'
        render action: 'invalid_token', status: :forbidden
        return
      end
    elsif params[:group_token]
      logger.debug 'Group token given'
      @group = Group.find_by_access_token(params[:group_token])

      unless @group
        render action: 'invalid_token', status: :forbidden
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
      logger.debug 'No group selected. Redirect to create group.'
      redirect_to new_exercise_group_path(exercise_id: @exercise.id)
      return
    end

    # Show group selection page if necessary
    if !@group && (@available_groups.size > 1 || @exercise.groupsizemax > 1 || @is_teacher)
      render action: 'select_group'
      log "select_group #{@exercise.id}"
      return
    end

    # Load previous submissions
    if @group
      @submissions = Submission.where(group_id: @group.id, exercise_id: @exercise.id).order('created_at DESC').all
    else
      @submissions = []
    end

    @submission = Submission.new
    log "submit view #{@exercise.id}"
  end

  def aplus_get
    if load_lti
      @submission = Submission.new
      CustomLogger.info("#{params['oauth_consumer_key']}/#{params[:user_id]} aplus GET success")
      log "submit view #{@exercise.id}"
    end
  end

  def aplus_submit
    return unless load_lti

    @submission = AplusSubmission.new(exercise: @exercise, authenticated: true, aplus_feedback_url: params['submission_url'])

    # Check that instance is active and student is enrolled
    unless @is_teacher || submission_policy_accepted?
      @status = 'error'
      return
    end
    logger.debug 'Submission policy accepted'

    # Group information comes from LTI
    @submission.group = @group

    # Check the file, TODO: check that both file and payload are not blank
    file_required = @exercise.submission_type.blank? || @exercise.submission_type == 'file'

    if file_required && params[:file].blank?
      logger.debug 'No file submitted'
      flash[:error] = t('submissions.new.missing_file')
      redirect_to submit_url(@exercise.id, member_token: params[:member_token], group_token: params[:group_token], ref: params[:ref])
      return
    end

    if params[:file].blank?
      t = Time.now
      @submission.filename = "#{t.year}-#{t.month}-#{t.day}.txt"
      @submission.extension = 'txt'
    else
      @submission.file = params[:file]
    end
    @submission.payload = params[:payload]

    if @submission.save
      logger.debug 'Submission accepted'
      @status = 'accepted'
      log "submit success #{@submission.id},#{@exercise.id}"
    else
      @status = 'error'
      flash[:error] = "Failed to submit. #{@submission.errors.full_messages.join('. ')}"
      log "submit fail #{@exercise.id} #{@submission.errors.full_messages.join('. ')}"
    end

    # Add user to course
    is_instructor = (params['roles']|| '').split(',').any? { |role| role.strip == 'Instructor' }
    if is_instructor
      @exercise.course_instance.course.teachers << @user unless @exercise.course_instance.course.teachers.include?(@user)
    else
      @exercise.course_instance.students << @user unless @exercise.course_instance.students.include?(@user)
    end

    logger.debug 'A+ Submission successful'
  end

  # TODO: use carrierwave to simplify file upload
  def create
    @user = current_user
    @submission = Submission.new(submission_params)
    @exercise = @submission.exercise
    load_course
    I18n.locale = @course_instance.locale || I18n.locale
    @is_teacher = @course.has_teacher(@user)

    return access_denied unless logged_in? || @course_instance.submission_policy == 'unauthenticated'
    logger.debug 'Login accepted'

    # Check that instance is active and student is enrolled
    return unless @is_teacher || submission_policy_accepted?
    logger.debug 'Submission policy accepted'

    if @submission.group
      # Check that user is member of group
      unless group_membership_validated(@submission.group) || @is_teacher
        render template: 'shared/forbidden', status: :forbidden, layout: 'wide'
        return
      end
      logger.debug 'Membership accepted'
    else
      logger.debug 'No group specified'
      if @exercise.groupsizemax <= 1 && current_user
        logger.debug 'Creating group of one'
        # Create a group automatically
        groupname = @user ? @user.studentnumber : 'untitled group'
        group = Group.new({course_instance_id: @course_instance.id, exercise_id: @exercise.id, name: groupname})
        group.save(validate: false)
        group.add_member(@user) if @user

        @submission.group = group
      else
        flash[:error] = 'No group selected'
        redirect_to submit_path(exercise: @submission.exercise_id, ref: params[:ref]), status: :bad_request
        return
      end
    end
    logger.debug 'Group accepted'

    # Check the file, TODO: check that both file and payload are not blank
    file_required = @exercise.submission_type.blank? || @exercise.submission_type == 'file'

    if file_required && params[:file].blank?
      logger.debug 'No file submitted'
      flash[:error] = t('submissions.new.missing_file')
      redirect_to submit_url(@exercise.id, member_token: params[:member_token], group_token: params[:group_token], ref: params[:ref])
      return
    end

    if params[:file].blank?
      t = Time.now
      @submission.filename = "#{t.year}-#{t.month}-#{t.day}.txt"
      @submission.extension = 'txt'
    else
      @submission.file = params[:file]
    end
    @submission.payload = params[:payload]

    # Check file extension
    if !@exercise.allowed_extensions.blank? && !@exercise.allowed_extensions.include?(@submission.extension)
      flash[:error] = "Extension #{@submission.extension} is not allowed."
      redirect_to submit_path(exercise: @submission.exercise_id, ref: params[:ref]), status: :bad_request
      return
    end

    # Store LTI launch params so that grades can be sent to LMS.
    # FIXME: Grades can only be sent to the submitter, not group members.
    # Is it better to not send any grades for group work?
    @submission.lti_launch_params = session[:lti_launch_params]

    if @submission.save
      logger.debug 'Submission accepted'
      flash[:success] = t('submissions.new.submission_received')
      log "submit success #{@submission.id},#{@exercise.id}"
    else
      flash[:error] = "Failed to submit. #{@submission.errors.full_messages.join('. ')}"
      log "submit fail #{@exercise.id} #{@submission.errors.full_messages.join('. ')}"
    end

    if request.format == 'json'
      # If post comes from Dropzone, don't do anything
      render :nothing => true, :status => 200
    elsif params[:ref] == 'exercises'
      redirect_to exercise_path(id: @submission.exercise_id)
    else
      redirect_to submit_path(exercise: @submission.exercise_id, group: @submission.group_id, member_token: params[:member_token], group_token: params[:group_token])
    end
  end

  # Assign to current user and start review
  def review
    return access_denied unless @course.has_teacher(current_user) || @submission.group.has_reviewer?(current_user) || (@exercise.collaborative_mode == 'review' && (@course_instance.has_student(current_user) || @course_instance.has_assistant(current_user)))

    review = @submission.assign_to(current_user, session[:lti_launch_params])

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
    #return access_denied unless @submission.reviews.empty?

    @submission.destroy
    log "delete_submission success #{@submission.id},#{@exercise.id}"

    redirect_to @exercise
  end

  def receive_email
    remote_ip = (request.env['HTTP_X_FORWARDED_FOR'] || request.remote_ip).split(',').first
    return access_denied unless ACCEPTED_EMAIL_SOURCES.include?(remote_ip)

    SubmissionMailer.receive(params[:email])
    head :created
  end

  private

  def submission_params
    params.require(:submission).permit(:exercise_id, :group_id)
  end

  def submission_policy_accepted?
    logger.debug 'Checking submission policy'

    # Check that instance is open
    if !@course_instance.active
      render action: 'instance_inactive'
      log "submit view #{@exercise.id} instance_inactive"
      logger.debug 'Instance inactive'
      return false
    end

    # Check enrollment
    if @course_instance.submission_policy == 'enrolled' && !@course_instance.students.include?(@user)
      render action: 'not_enrolled'
      log "submit view #{@exercise.id} not_enrolled"
      logger.debug 'Not enrolled'
      return false
    end

    return true
  end

  def load_lti
    # Authorized IP?
    remote_ip = (request.env['HTTP_X_FORWARDED_FOR'] || request.remote_ip).split(',').first
    unless APLUS_IP_WHITELIST.include? remote_ip
      @heading = 'LTI error: Requests only allowed from A+'
      render template: 'shared/error'
      return false
    end

    # Find exercise
    organization = Organization.find_by_domain(params['oauth_consumer_key']) || Organization.create(domain: params['oauth_consumer_key'])

    @course_instance = CourseInstance.where(lti_consumer: params['oauth_consumer_key'], lti_context_id: params[:context_id]).first
    unless @course_instance
      @heading = 'This LTI course is not configured'
      logger.warn "LTI login failed. Could not find a course instance with lti_consumer=#{params['oauth_consumer_key']}, lti_context_id=#{params[:context_id]}"
      render template: 'shared/error'
      return false
    end

    @course = @course_instance.course
    @is_assistant = @course_instance.has_assistant(current_user)
    @is_teacher = @course.has_teacher(current_user)
    I18n.locale = @course_instance.locale || I18n.locale

    @exercise = Exercise.where(course_instance_id: @course_instance.id, lti_resource_link_id: params[:resource_link_id]).first
    unless @exercise
      @heading = 'This LTI exercise is not configured'
      render template: 'shared/error'
      return false
    end

    # TODO: if teacher, create exercise

    # Find or create user, TODO: handle errors
    @user = User.where(lti_consumer: params['oauth_consumer_key'], lti_user_id: params[:user_id]).first
    if @user
      # Update attributes
      @user.email = params['lis_person_contact_email_primary']
      @user.save(validate: false)
    else
      @user = lti_create_user(params['oauth_consumer_key'], params[:user_id], organization, @exercise.course_instance, params[:custom_student_id], params['lis_person_name_family'], params['lis_person_name_given'], params['lis_person_contact_email_primary'])
    end
    @is_teacher = @course.has_teacher(current_user)

    # Create or find group, TODO: handle errors
    @group = if params[:custom_group_members]
               logger.info("LTI request: #{params[:custom_group_members]}")
               lti_find_or_create_group(JSON.parse(params[:custom_group_members]), @exercise, @user, organization, params['oauth_consumer_key'])
             else
               lti_find_or_create_group([{'user' => params[:user_id], 'email' => params[:lis_person_contact_email_primary], 'name' => ''}], @exercise, @user, organization, params['oauth_consumer_key'])
             end

    return true
  end
end
