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
      unless @course.has_teacher(current_user) || is_admin?(current_user)
        flash[:error] = "Unauthorized"
        redirect_to @course
        return
      end

      @groups = @exercise.groups

      @graders = Array.new
      @graders.concat(@course.teachers.collect {|u| [u.name, u.id]})
      @graders << ['= Assistants =', 'assistants']
      @graders.concat(@course_instance.assistants.collect {|u| [u.name, u.id]})
      @graders << ['= Students =', 'students']
      @graders.concat(@course_instance.students.collect {|u| [u.name, u.id]})
      render :action => 'manage'
    else
      # Student's or assistant's view

      # Find reviews of the user
      @reviews = Review.find(:all, :conditions => [ "user_id = ? AND exercise_id = ?", current_user.id, @exercise.id], :joins => 'JOIN submissions ON submissions.id = submission_id', :order => 'submissions.group_id, submissions.created_at DESC')

      # Find groups of the user
      @group = Group.find(:first, :conditions => ["user_id = ? AND exercise_id = ?", current_user.id, @exercise.id], :joins => 'JOIN groups_users ON groups_users.group_id = id')
    end
  end

  def results
    @exercise = Exercise.find(params[:id])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = "You are not authorized to view results"
      redirect_to @course_instance
      return
    end

    @groups = @exercise.groups
  end
  
  def statistics
    @exercise = Exercise.find(params[:id])
    load_course
    
    # Authorization
    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = "You are not allowed to view statistics"
      redirect_to @course
      return
    end
    
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

  # GET /exercises/new
  def new
    @course_instance = CourseInstance.find(params[:ci])
    @course = @course_instance.course
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = "You are not authorized to create exercises"
      redirect_to @course_instance
      return
    end

    @exercise = Exercise.new

    rescue
      @heading = 'Error'
      @message = 'Course instance not specified'
      render :template => "shared/error"
  end

  # Action for uploading an XML file
  def upload
    @exercise = Exercise.find(params[:id])
    load_course

    # Authorization
    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = "Unauthorized"
      redirect_to @exercise
      return
    end

    file = params[:xml][:file] if params[:xml] && params[:xml][:file]

    # Check that a file is uploaded
    unless [ActionController::UploadedStringIO, ActionController::UploadedTempfile].include?(file.class) and file.size.nonzero?
      return
    end

    # Load xml
    @exercise.load_xml(params[:xml][:file])

    redirect_to :controller => 'rubrics', :action => 'edit', :id => @exercise.id
  end

  def download
    @exercise = Exercise.find(params[:id])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = "Unauthorized"
      redirect_to @exercise
      return
    end

    xml = @exercise.generate_xml
    send_data(xml, :filename => "#{@exercise.name}.xml", :type => 'text/xml')

    #redirect_to :controller => 'exercises', :action => 'show', :id => @exercise.id
    #redirect_to @exercise
  end


  # GET /exercises/1/edit
  def edit
    @exercise = Exercise.find(params[:id])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = "You are not authorized to edit"
      redirect_to @course
      return
    end
  end

  # POST /exercises
  def create
    @exercise = Exercise.new(params[:exercise])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = "You are not authorized to create exercises"
      redirect_to @course_instance
      return
    end

    if @exercise.save
      @exercise.initialize_example

      flash[:success] = 'Exercise was successfully created.'
      redirect_to @exercise
    else
      render :action => "new"
    end
  end

  # PUT /exercises/1
  def update
    @exercise = Exercise.find(params[:id])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = "You are not authorized to edit"
      redirect_to @course_instance
      return
    end

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

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = "You are not authorized to delete"
      redirect_to @course_instance
      return
    end

    @exercise.destroy

    respond_to do |format|
      format.html { redirect_to @course_instance }
      format.xml  { head :ok }
    end
  end

  # Mails selected submissions and reviews
  def send_selected_reviews
    @exercise = Exercise.find(params[:eid])
    load_course

    # Authorization
    unless @course.has_teacher(current_user) || is_admin?(current_user)
      head :forbidden
      return
    end

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
  def remove_selected_submissions
    @exercise = Exercise.find(params[:eid])
    load_course

    # Authorization
    unless @course.has_teacher(current_user) || is_admin?(current_user)
      head :forbidden
      return
    end

    # Iterate through submissions checkboxes
    if params[:submissions_checkboxes]
      params[:submissions_checkboxes].each do |id, value|
        Submission.destroy(id) if value == '1'
      end
    end

    # Iterate through reviews checkboxes
    if params[:reviews_checkboxes]
      params[:reviews_checkboxes].each do |id, value|
        Review.destroy(id) if value == '1'
      end
    end

    render :partial => 'group', :collection => @exercise.groups
  end


  # Assigns selected submissions to the selected user
  def assign_submissions
    @exercise = Exercise.find(params[:eid])
    load_course

    # Authorization
    unless @course.has_teacher(current_user) || is_admin?(current_user)
      head :forbidden
      return
    end

    # Select checked submissions
    submissions = Array.new
    params[:submissions_checkboxes].each do |id, value|
      submissions << Submission.find(id) if value == '1'
    end

    exclusive = params[:exclusive] == 'true'

    # Assign
    if (params[:assistant] == 'assistants')
      @exercise.assign(submissions, @course_instance.assistants, exclusive)
    elsif (params[:assistant] == 'students')
      @exercise.assign(submissions, @course_instance.students, exclusive)
    else
      @exercise.assign(submissions, [User.find(params[:assistant])], exclusive)
    end

    render :partial => 'group', :collection => @exercise.groups
  end


  # Assign selected submissions to the exclusively to the selected user.
  # Existing reviews are deleted.
  def assign_submissions_exclusive
    @exercise = Exercise.find(params[:eid])
    load_course

    # Authorization
    unless @course.has_teacher(current_user) || is_admin?(current_user)
      head :forbidden
      return
    end

    params[:submissions_checkboxes].each do |id, value|
      if value == '1' && !params[:assistant].empty?
        logger.info("Assigning to #{params[:assistant]}")
        Submission.find(id).assign_to_exclusive(params[:assistant])
      end
    end

    render :partial => 'group', :collection => @exercise.groups
  end

  def assign_assistants_randomly
    @exercise = Exercise.find(params[:eid])
    load_course

    # Authorization
    unless @course.has_teacher(current_user) || is_admin?(current_user)
      head :forbidden
      return
    end

    @exercise.assign_assistants_evenly
    render :partial => 'group', :collection => @exercise.groups
  end

  def assign_assistants_evenly
    @exercise = Exercise.find(params[:eid])
    load_course

    # Authorization
    unless @course.has_teacher(current_user) || is_admin?(current_user)
      head :forbidden
      return
    end

    @exercise.assign_assistants_evenly
    render :partial => 'group', :collection => @exercise.groups
  end

  def batch_assign
    @exercise = Exercise.find(params[:id])
    load_course

    # Authorization
    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = "Unauthorized"
      redirect_to @course
      return
    end

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
    @exercise.archive
  end
  
end
