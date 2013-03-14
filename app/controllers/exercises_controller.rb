class ExercisesController < ApplicationController
  before_filter :login_required

  # GET /exercises/manage/1
#   def manage
#     @exercise = Exercise.find(params[:id])
#     load_course
#
#     # Authorization
#     unless @course.has_teacher(current_user) || is_admin?(current_user)
#       flash[:error] = "Unauthorized"
#       redirect_to @course
#       return
#     end
#
#     @groups = @exercise.groups
#
#     @graders = Array.new
#     @graders.concat(@course.teachers.collect {|u| [u.name, u.id]})
#     @graders << ['= Assistants =', 'assistants']
#     @graders.concat(@course_instance.assistants.collect {|u| [u.name, u.id]})
#     @graders << ['= Students =', 'students']
#     @graders.concat(@course_instance.students.collect {|u| [u.name, u.id]})
#   end

  # GET /exercises/1
  def show
    @exercise = Exercise.find(params[:id])
    load_course

    if @course.has_teacher(current_user) || is_admin?(current_user)
      # Teacher's view

      @exercise = Exercise.find(params[:id])
      load_course

      # Authorization
      return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

      @groups = Group.where(:course_instance_id => @course_instance.id).includes([:users, {:submissions => {:reviews => :user}}]).where(:submissions => {:exercise_id => @exercise.id}).order('groups.id')

      render :action => 'submissions'
    else
      # Student's or assistant's view

      # Find reviews of the user
      assigned_group_ids = current_user.assigned_group_ids
      @assigned_groups = Group.where(:id => assigned_group_ids).includes([:users, {:submissions => {:reviews => :user}}]).where(:submissions => {:exercise_id => @exercise.id}).order('groups.id').all
      
      #Review.find(:all, :conditions => [ "user_id = ? AND exercise_id = ?", current_user.id, @exercise.id], :joins => 'JOIN submissions ON submissions.id = submission_id', :order => 'submissions.group_id, submissions.created_at DESC')

      # Find groups of the user
      @available_groups = Group.where('course_instance_id=? AND user_id=?', @course_instance.id, current_user.id).joins(:users).all
      
      render :action => 'my_submissions'
    end
  end

  # GET /exercises/new
  def new
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @exercise = Exercise.new
  end

  # POST /exercises
  def create
    @exercise = Exercise.new(params[:exercise])
    @exercise.course_instance_id = params[:course_instance_id]
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    if @exercise.save
      @exercise.initialize_example

      flash[:success] = 'Exercise was successfully created.'
      redirect_to @exercise
    else
      render :action => "new"
    end
  end

  # GET /exercises/1/edit
  def edit
    @exercise = Exercise.find(params[:id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
  end

  # PUT /exercises/1
  def update
    @exercise = Exercise.find(params[:id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    if @exercise.update_attributes(params[:exercise])
      flash[:success] = 'Exercise was successfully updated.'
      redirect_to @exercise
    else
      render :action => "edit"
    end
  end

  # DELETE /exercises/1
  # DELETE /exercises/1.xml
  def destroy
    @exercise = Exercise.find(params[:id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @exercise.destroy

    respond_to do |format|
      format.html { redirect_to @course_instance }
      format.xml  { head :ok }
    end
  end

  def results
    @exercise = Exercise.find(params[:id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @groups = @exercise.groups
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
  def send_selected_reviews
    @exercise = Exercise.find(params[:eid])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    # Iterate through submissions checkboxes
    if params[:submissions_checkboxes]
      params[:submissions_checkboxes].each do |id, value|
        next unless value == '1'
        submission = Submission.find(id) if value == '1'

        # Send all reviews
        submission.reviews.each do |review|
          logger.info("sending review #{review.id}")
          Mailer.deliver_review(review) if review && (review.status == 'finished' || review.status == 'mailed')
        end
      end
    end

    # Iterate through reviews checkboxes
    if params[:reviews_checkboxes]
      params[:reviews_checkboxes].each do |id, value|
        next unless value == '1'
        review = Review.find(id)
        logger.info("sending review #{review.id}")
        Mailer.deliver_review(review) if review && (review.status == 'finished' || review.status == 'mailed')
      end
    end

    render :partial => 'group', :collection => @exercise.groups
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

    tempfile = @exercise.archive(:only_latest => true)
    send_file tempfile.path(), :type => 'application/x-gzip', :filename => "rybyric-exercise-#{@exercise.id}.tar.gz"
    tempfile.unlink
  end

  def create_example_submissions
    @exercise = Exercise.find(params[:exercise_id])
    load_course
    authorize! :update, @course_instance
    
    @course_instance.create_example_groups(10) if @course_instance.groups.empty?
    @exercise.create_example_submissions
    
    redirect_to @exercise
  end

end
