class CourseInstancesController < ApplicationController
  before_filter :login_required #, :except => [:show]

  # GET /course_instances/1
  def show
    @course_instance = CourseInstance.find(params[:id])
    load_course

    @allow_edit = @course.has_teacher(current_user) || is_admin?(current_user)
  end

  # GET /course_instances/new
  # GET /course_instances/new.xml
  def new
    # Load course
    begin
      @course = Course.find(params[:course])
    rescue
      @heading = 'Error'
      @message = 'Course not specified'
      render :template => "shared/error"
      return
    end
    @is_teacher = @course.has_teacher(current_user)

    # Authorize
    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = 'You are not authorized to create course instances.'
      redirect_to @course
      return
    end

    @course_instance = CourseInstance.new
  end

  # GET /course_instances/1/edit
  def edit
    @course_instance = CourseInstance.find(params[:id])
    load_course

    # Authorize
    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = 'You are not authorized to edit course instances.'
      redirect_to @course
    end
  end

  # POST /course_instances
  # POST /course_instances.xml
  def create
    @course_instance = CourseInstance.new(params[:course_instance])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = 'You are not authorized to create a course instance.'
      redirect_to @course
      return
    end

    if @course_instance.save
      flash[:success] = 'Course instance was successfully created.'
      redirect_to @course_instance
    else
      render :action => 'new'
    end
  end

  # PUT /course_instances/1
  def update
    @course_instance = CourseInstance.find(params[:id])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = 'You are not authorized to edit.'
      redirect_to @course
      return
    end

    if @course_instance.update_attributes(params[:course_instance])
      flash[:success] = 'Course instance was successfully updated.'
      redirect_to @course_instance
    else
      flash[:success] = 'Failed to update.'
      render :action => "edit"
    end
  end

  # DELETE /course_instances/1
  def destroy
    @course_instance = CourseInstance.find(params[:id])
    load_course

    # Authorize
    unless @course.has_teacher(current_user)
      flash[:error] = 'You are not authorized to delete course instances.'
      redirect_to @course_instance
      return
    end

    #Destroy
    @course_instance.destroy
    redirect_to(@course)
  end


  def students
    @course_instance = CourseInstance.find(params[:id])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = 'You are not authorized view students.'
      redirect_to @course_instance
      return
    end

    if params[:csv] && params[:csv][:file]
      # FIXME: this is a temporary hack
      skipped_students = @course_instance.add_students_csv(params[:csv][:file].read)

      if skipped_students.size > 0
        msg = 'The following students could not be created: ' + skipped_students.join(', ') + '. Check character encoding.'
        flash[:error] = msg
      end
    end
  end

  # Ajax action for uploading a csv student list
  def students_csv
    @course_instance = CourseInstance.find_by_id(params[:course_instance_id])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      head :forbidden
      return
    end

    if params[:paste]
      @course_instance.add_students_csv(params[:paste])
    end

    render :partial => 'user', :collection => @course_instance.students, :locals => { :iid => @course_instance.id }
  end

  # Ajax action for removing a single user from the course instance.
  # iid must be set to the course instance id, and uid to the user id.
  def remove_user
    @course_instance = CourseInstance.find_by_id(params[:iid])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      head :forbidden
      return
    end

    @course_instance.remove_student(params[:uid])

    render :update do |page|
      page.remove "user#{params[:uid]}"
    end
  end

  # Ajax action for deleting multiple students
  def remove_selected_students
    @course_instance = CourseInstance.find_by_id(params[:course_instance_id])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      head :forbidden
      return
    end

    students = Array.new
    @course_instance.students.each do |student|
      if params["selector#{student.id}"]
        students << student
      end
    end
    @course_instance.remove_students(students)

    render :partial => 'user', :collection => @course_instance.students, :locals => { :iid => @course_instance.id }
  end

  def assistants
    @course_instance = CourseInstance.find(params[:id])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      flash[:error] = 'You are not authorized view teaching assistants.'
      redirect_to @course_instance
      return
    end

    if params[:csv] && params[:csv][:file]
      @course_instance.add_assistants_csv(params[:csv][:file].read)
    end
  end

  # Ajax action for uploading a csv stundent list
  def add_assistants_csv
    @course_instance = CourseInstance.find_by_id(params[:course_instance_id])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      head :forbidden
      return
    end

    if params[:paste]
      @course_instance.add_assistants_csv(params[:paste])
    end

    render :partial => 'user', :collection => @course_instance.assistants, :locals => { :iid => @course_instance.id }
  end

  # Ajax action for deleting multiple assistants
  def remove_selected_assistants
    @course_instance = CourseInstance.find_by_id(params[:course_instance_id])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      head :forbidden
      return
    end

    users = Array.new
    @course_instance.assistants.each do |user|
      if params["selector#{user.id}"]
        users << user
      end
    end
    @course_instance.remove_assistants(users)

    render :partial => 'user', :collection => @course_instance.assistants, :locals => { :iid => @course_instance.id }
  end

end
