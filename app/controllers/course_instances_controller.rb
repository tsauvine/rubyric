class CourseInstancesController < ApplicationController
  before_filter :login_required

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
    @course = Course.find(params[:course_id])
    load_course

    # Authorize
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @course_instance = CourseInstance.new
  end

  # GET /course_instances/1/edit
  def edit
    @course_instance = CourseInstance.find(params[:id])
    load_course

    # Authorize
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
  end

  # POST /course_instances
  # POST /course_instances.xml
  def create
    # Load course
    @course = Course.find(params[:course_id])
    load_course
    
    @course_instance = CourseInstance.new(params[:course_instance])
    @course_instance.course_id = @course.id

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    if @course_instance.save
      flash[:success] = t(:instance_created_flash)
      redirect_to @course_instance
    else
      render :action => 'new'
    end
  end

  # PUT /course_instances/1
  def update
    @course_instance = CourseInstance.find(params[:id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    if @course_instance.update_attributes(params[:course_instance])
      flash[:success] = t(:instance_updated_flash)
      redirect_to @course_instance
    else
      render :action => "edit"
    end
  end

  # DELETE /course_instances/1
  def destroy
    @course_instance = CourseInstance.find(params[:id])
    load_course

    # Authorize
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    #Destroy
    @course_instance.destroy
    redirect_to(@course)
  end


  def students
    @course_instance = CourseInstance.find(params[:id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    if params[:csv] && params[:csv][:file]
      skipped_students = @course_instance.add_students_csv(params[:csv][:file].read)

      # FIXME;
#       if skipped_students.size > 0
#         msg = 'The following students could not be created: ' + skipped_students.join(', ') + '. Check character encoding.'
#         flash[:error] = msg
#       end
    end
  end

  # Ajax action for uploading a csv student list
  def students_csv
    @course_instance = CourseInstance.find_by_id(params[:course_instance_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

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

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @course_instance.remove_student(params[:uid])

    render :update do |page|
      page.remove "user#{params[:uid]}"
    end
  end

  # Ajax action for deleting multiple students
  def remove_selected_students
    @course_instance = CourseInstance.find_by_id(params[:course_instance_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

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

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    if params[:csv] && params[:csv][:file]
      @course_instance.add_assistants_csv(params[:csv][:file].read)
    end
  end

  # Ajax action for uploading a csv stundent list
  def add_assistants_csv
    @course_instance = CourseInstance.find_by_id(params[:course_instance_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    if params[:paste]
      @course_instance.add_assistants_csv(params[:paste])
    end

    render :partial => 'user', :collection => @course_instance.assistants, :locals => { :iid => @course_instance.id }
  end

  # Ajax action for deleting multiple assistants
  def remove_selected_assistants
    @course_instance = CourseInstance.find_by_id(params[:course_instance_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

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
