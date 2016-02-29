require 'set.rb'

class ExercisesController < ApplicationController
  before_filter :login_required, :except => [:lti]

  def lti
      # Temporarily disable signature checking
#       unless authenticate_lti_signature
#         logger.info "Failed to auth LTI signature"
#         return
#       end
    unless login_lti_user
      logger.info "Failed to login LTI user"
      return
    end

    redirect_to @exercise
  end
  
  # GET /exercises/1
  def show
    @exercise = Exercise.find(params[:id])
    load_course
    I18n.locale = @course_instance.locale || I18n.locale
    
    if @course.has_teacher(current_user) || is_admin?(current_user)
      # Teacher's view
      @groups = @exercise.groups_with_submissions.order('groups.id, submissions.created_at DESC, reviews.id')
      
      render :action => 'submissions', :layout => 'fluid-new'
    else
      # Student's or assistant's view
      @is_assistant = @course_instance.has_assistant(current_user)
      
      # Find reviews assigned to the user
      # TODO: move to model
      explicitly_assigned_groups = Set.new(current_user.assigned_group_ids)
      @assigned_groups = Set.new
      
      # Find peer groups whose submissions the user can view
      @viewable_peer_groups = Set.new
      
      @exercise.groups_with_submissions.order('submissions.created_at DESC, reviews.id').each do |group|
        @assigned_groups << group if explicitly_assigned_groups.include?(group.id)
        
        group.submissions.each do |submission|
          @viewable_peer_groups << group if @exercise.collaborative_mode != '' && !group.users.include?(current_user)
            
          submission.reviews.each do |review|
            @assigned_groups << group if review.user == current_user
          end
        end
      end

      @assigned_groups = @assigned_groups.to_a
      @viewable_peer_groups = @viewable_peer_groups.to_a
      
      # Find groups of the user
      @available_groups = Group.where('course_instance_id=? AND user_id=?', @course_instance.id, current_user.id).joins(:users).all
      
      # How many submissions does the user have?
      # FIXME: this is a quick hack, probably inefficient
      @own_submission_count = 0
      @available_groups.each do |group|
        submissions = group.submissions.where(:exercise_id => @exercise.id)
        @own_submission_count += submissions.size
      end
      
      render :action => 'my_submissions', :layout => 'fluid-new'
    end
    
    log "exercise view #{@exercise.id}"
  end

  # GET /exercises/new
  def new
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @exercise = Exercise.new
    
    log "create_exercise view #{@course_instance.id}"
  end

  # POST /exercises
  def create
    @exercise = Exercise.new(params[:exercise])
    @exercise.course_instance_id = params[:course_instance_id]
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    if @exercise.save
      @exercise.initialize_example

      #flash[:success] = 'Assignment was successfully created.'
      redirect_to @exercise
      log "create_exercise success #{@exercise.id}"
    else
      render :action => "new"
      log "create_exercise fail #{@exercise.errors.full_messages.join('. ')}"
    end
  end

  # GET /exercises/1/edit
  def edit
    @exercise = Exercise.find(params[:id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
    
    log "edit_exercise view #{@exercise.id}"
  end

  # PUT /exercises/1
  def update
    @exercise = Exercise.find(params[:id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    if @exercise.update_attributes(params[:exercise])
      #flash[:success] = 'Assignment was successfully updated.'
      redirect_to @exercise
      log "edit_exercise success #{@exercise.id}"
    else
      render :action => "edit"
      log "edit_exercise fail #{@exercise.errors.full_messages.join('. ')}"
    end
  end

  # DELETE /exercises/1
  # DELETE /exercises/1.xml
  def destroy
    @exercise = Exercise.find(params[:id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    log "delete_exercise success #{@exercise.id}"
    @exercise.destroy

    respond_to do |format|
      format.html { redirect_to @course_instance }
      format.xml  { head :ok }
    end
  end

  def results
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @results = [] # [[member, review], [member, review], ...]
    @groups = Group.where(:course_instance_id => @course_instance.id).includes([{:submissions => [:reviews => :user, :group => :users]}, :users])
    
    @groups.each do |group|
      best_review = nil
      best_grade = Float::MIN
      all_reviews = []
      
      # Collect the reviews that should be included in the results
      group.submissions.each do |submission|
        next unless submission.exercise_id == @exercise.id
        submission.reviews.each do |review|
          next unless review.include_in_results?
          
          # Determine grade
          grade = Float(review.grade) rescue Float::MIN
          
          if !grade.nil? && (best_review.nil? || grade > best_grade)
            best_review = review
            best_grade = grade
          end
          
          all_reviews << review
        end
      end
      
      if !params[:all_reviews] && best_review
        @results.concat group.group_members.collect {|member| [member, best_review]}
      else
        group.group_members.each do |member|
          all_reviews.each do |review|
            @results << [member, review]
          end
        end
      end
    end
    
    @results.sort! { |a, b| (a[0].studentnumber || '') <=> (b[0].studentnumber || '') }
    
    log "results #{@exercise.id}"
  end
  
  def student_results
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @results = @exercise.student_results
    log "student_results #{@exercise.id}"
  end

  def statistics
    @exercise = Exercise.find(params[:id])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    graders = @course.teachers + @course_instance.assistants

    @histograms = []

    # All graders
    histogram = @exercise.grade_distribution()
    total = 0
    histogram.each { |pair| total += pair[1] }
    @histograms << {:grader => 'All', :histogram => histogram, :total => total}

    # Each grader
    graders.each do |grader|
      histogram  = @exercise.grade_distribution(grader)
      total = 0
      histogram.each { |pair| total += pair[1] }

      @histograms << {:grader => grader.name, :histogram => histogram, :total => total}
    end
  end

  # Mails selected submissions and reviews
  def send_reviews
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    # Collect selected review ids
    review_ids = (params[:reviews_checkboxes] || []).reject {|id, value| value != '1'}.keys
    @exercise.deliver_reviews(review_ids)
    
    redirect_to @exercise
    log "send_reviews #{@exercise.id} #{review_ids.size}"
  end

  # Removes selected submissions and reviews
#   def remove_selected_submissions
#     @exercise = Exercise.find(params[:eid])
#     load_course
#
#     # Authorization
#     return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
#
#     # Iterate through submissions checkboxes
#     if params[:submissions_checkboxes]
#       params[:submissions_checkboxes].each do |id, value|
#         Submission.destroy(id) if value == '1'
#       end
#     end
#
#     # Iterate through reviews checkboxes
#     if params[:reviews_checkboxes]
#       params[:reviews_checkboxes].each do |id, value|
#         Review.destroy(id) if value == '1'
#       end
#     end
#
#     render :partial => 'group', :collection => @exercise.groups
#   end


  # Assigns selected submissions to the selected user
  def assign
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    # Select checked submissions
    submission_ids = Array.new
    if params[:submissions_checkboxes]
      params[:submissions_checkboxes].each do |id, value|
        submission_ids << Integer(id) if value == '1'
      end
    end

    # Select checked reviews
    review_ids = Array.new
    if params[:reviews_checkboxes]
      params[:reviews_checkboxes].each do |id, value|
        review_ids << Integer(id) if value == '1'
      end
    end

    #exclusive = params[:exclusive] == 'true'

    if params[:assign]
      # Assign
      if params[:assistant] == 'assistants'
        @exercise.assign(submission_ids, @course_instance.assistant_ids)
      elsif params[:assistant] == 'students'
        @exercise.assign(submission_ids, @course_instance.student_ids)
      else
        @exercise.assign(submission_ids, [Integer(params[:assistant])])
      end

      redirect_to @exercise
    elsif params[:mail]

    elsif params[:delete]
      @reviews = Review.find(review_ids)

      render :delete_reviews
    else
      redirect_to @exercise
    end
  end


  def delete_reviews
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    # Read review list
    counter = 0
    if params[:reviews]
      review_ids = Array.new
      params[:reviews].each do |id, value|
        review_ids << Integer(id) if value == '1'
      end

      # Delete reviews
      reviews = Review.find(review_ids)
      reviews.each do |review|
        review.destroy
      end

      counter = review_ids.size
    end

    redirect_to @exercise, :flash => {:success => "#{counter} reviews deleted" }
  end

  def batch_assign
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    # Process CSV
    if params[:paste]
      counter = @exercise.batch_assign(params[:paste])
      flash[:success] = "#{counter} new assignments"
      redirect_to @exercise
    end

    if params[:csv] && params[:csv][:file]
      counter = @exercise.batch_assign(params[:csv][:file].read)
      flash[:success] = "#{counter} new assignments"
      redirect_to @exercise
    end
  end

  def archive
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    begin
      archive_path = @exercise.archive(:only_latest => true)
      send_file archive_path, :type => 'application/x-gzip', :filename => @exercise.archive_filename
    ensure
      # TODO: delete tempdir and archive
      #File.delete(archive_path)
    end
  end

  def create_example_submissions
    @exercise = Exercise.find(params[:exercise_id])
    load_course
    authorize! :update, @course_instance
    
    @course_instance.create_example_groups(10) if @course_instance.groups.empty?
    @exercise.create_example_submissions
    
    redirect_to @exercise
    
    log "create_example_submissions #{@exercise.id}"
  end

  # Assign to current user and start review
  def create_peer_review
    @exercise = Exercise.find(params[:exercise_id])
    load_course
    return access_denied unless @course_instance.has_student(current_user) || @course_instance.has_assistant(current_user) || @course.has_teacher(current_user)

    # TODO: move most of this to model
    review = nil
    submission = nil
    Exercise.transaction do
      # Count the reviews of each group. Skip user's own groups.
      # result: [ {:group => Group, :count => integer}, ... ]
      review_counts = []
      @exercise.groups_with_submissions.each do |group|
        next if group.users.include?(current_user)
        next if group.submissions.empty?
        
        review_count = 0
        skip = false
        group.submissions.each do |submission|
          review_count += submission.reviews.size
          skip = true if submission.reviews.any? {|review| review.user == current_user}
        end
        next if skip
        
        review_counts << {:group => group, :count => review_count }
      end
      
      if review_counts.empty?
        redirect_to @exercise, :warning => 'Nothing to review'
        return
      end

      # Select the group with the least reviews
      review_counts.sort! {|a,b| a[:count] <=> b[:count]}
      group = review_counts.first
      submission = group[:group].submissions.last
      
      review = submission.assign_to(current_user)
    end

    redirect_to edit_review_path(review)
    log "create_peer_review #{submission.id},#{@exercise.id}"
  end

  
end
