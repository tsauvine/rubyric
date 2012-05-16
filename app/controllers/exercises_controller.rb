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

      #@groups = @exercise.groups
      @groups = Group.find_all_by_exercise_id(@exercise.id, :include => [:users, {:submissions => {:reviews => :user}}], :order => 'name, id')

      @graders = Array.new
      @graders.concat(@course.teachers.collect {|u| [u.name, u.id]})
      @graders << ['= Assistants =', 'assistants']
      @graders.concat(@course_instance.assistants.collect {|u| [u.name, u.id]})

#       if @exercise.peer_review
#         @graders << ['= Students =', 'students']
#         @graders.concat(@course_instance.students.collect {|u| [u.name, u.id]})
#       end

      # Count submissions per grader
      @grader_workload = []
      (@course.teachers + @course_instance.assistants).each do |grader|
        count = Review.count(:conditions => ['exercise_id = ? AND user_id = ?', @exercise.id, grader.id], :joins => 'JOIN submissions ON reviews.submission_id = submissions.id')
        @grader_workload << [grader, count]
      end

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

    @groups = Group.find_all_by_exercise_id(@exercise.id, :include => [:users, {:submissions => {:reviews => :user}}], :order => 'name, id')
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
    histogram = @exercise.grade_distribution
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
    if file.nil?
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

  # Create example submissions
  def create_submissions
    @exercise = Exercise.find(params[:id])
    load_course

    access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @exercise.create_example_submissions

    redirect_to @exercise
  end


  def assign
    @exercise = Exercise.find(params[:id])
    load_course

    # Authorization
    access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    # Get ids of selected submissions
    submission_ids = []
    if params[:submissions_checkboxes]
      params[:submissions_checkboxes].each do |id, value|
        submission_ids << Integer(id) if value == '1'
      end
    end

    #Review.where(:submission_id => submission_ids, :status => ['finished', 'mailed']).select(:id).each do |review|
    #  review_ids << review.id
    #end

    # Get ids of selected reviews
    review_ids = []
    if params[:reviews_checkboxes]
      params[:reviews_checkboxes].each do |id, value|
        review_ids << Integer(id) if value == '1'
      end
    end

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
      if review_ids.empty?
        flash[:error] = "No reviews were selected. Make sure to select reviews, not submissions."

        redirect_to @exercise
      else
        # Update status
        Review.update_all("status='mailing'", :id => review_ids, :status => ['finished', 'mailed'])

        # Send reviews with delayed job
        Exercise.delay.deliver_reviews(review_ids) unless review_ids.empty?

        flash[:success] = "Reviews will be mailed shortly. Status of the reviews will be updated to 'mailed' after they have been sent."

        redirect_to @exercise
      end
    elsif params[:delete]
      Review.destroy(review_ids)

      redirect_to @exercise
    else
      redirect_to @exercise
    end

    #render :partial => 'group', :collection => @exercise.groups
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
    @exercise = Exercise.find(params[:id])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
     flash[:error] = "Unauthorized"
     redirect_to @course
     return
    end

    tempfile = @exercise.archive(:only_latest => true)
    send_file tempfile.path(), :type => 'application/x-gzip', :filename => "rybyric-exercise-#{@exercise.id}.tar.gz"
  end

  def assignments
    @exercise = Exercise.find(params[:id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @assignments = {}  # {group => [graders], gropu => [graders]}
    @exercise.groups.each do |group|
      graders = Set.new
      group.submissions.each do |submission|
        submission.reviews.each do |review|
          graders << review.user
        end
      end

      @assignments[group] = graders
    end
  end

end
