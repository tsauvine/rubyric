class CoursesController < ApplicationController
  before_filter :login_required #, :except => [:index, :show]

  # GET /courses
  def index
    if is_admin?(current_user)
      @courses = Course.find(:all, :order => "code")
      @allow_create = true
    else
      # TODO: show own courses
      @courses = Course.find(:all, :order => "code")
    end
  end

  # GET /courses/1
  def show
    @course = Course.find(params[:id])
    @is_teacher = @course.has_teacher(current_user) || is_admin?(current_user)
  end

  # GET /courses/new
  # GET /courses/new.xml
  def new
    @course = Course.new
  end

  # GET /courses/1/edit
  def edit
    @course = Course.find(params[:id])
    @is_teacher = @course.has_teacher(current_user) || is_admin?(current_user)

    return access_denied unless @is_teacher
  end

  # POST /courses
  def create
    @course = Course.new(params[:course])

    if @course.save
      @course.teachers << current_user

      flash[:success] = 'New course was successfully created. Next, create a course instance.'
      redirect_to new_course_instance_path(:course => @course.id)
    else
      render :action => "new"
    end

  end

  # PUT /courses/1
  def update
    @course = Course.find(params[:id])
    @is_teacher = @course.has_teacher(current_user) || is_admin?(current_user)

    return access_denied unless @is_teacher

    if @course.update_attributes(params[:course])
      flash[:success] = 'Course was successfully updated.'
      redirect_to(@course)
    else
      render :action => "edit"
    end
  end

  # DELETE /courses/1
  def destroy
    @course = Course.find(params[:id])
    name = @course.name

    if @course.has_teacher(current_user) || is_admin?(current_user)
      if @course.destroy
        flash[:success] = "#{name} was successfully deleted."
      end
      redirect_to(courses_url)
    else
      flash[:error] = "You are not authorized to delete #{name}."
      redirect_to :action => :index
    end
  end

  def teachers
    @course = Course.find(params[:id])
  end

  # Ajax
  def add_teacher
    @course = Course.find(params[:course_id])

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    unless params[:studentnumber].blank?
      user = User.find_by_studentnumber(params[:studentnumber])

      if user
        # Existing
        @course.teachers << user
      else
        # Create new
        logger.info("#{params[:studentnumber]} not found. Creating")
        user = User.new
        user.studentnumber = params[:studentnumber]
        user.firstname = params[:firstname]
        user.lastname = params[:lastname]
        user.email = params[:email]
        user.password = params[:password]
        user.save

        @course.teachers << user
      end
    end

    render :partial => 'user', :collection => @course.teachers, :locals => { :cid => @course.id }
  end

  # Ajax action for deleting multiple teachers
  def remove_selected_teachers
    @course = Course.find(params[:course_id])

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      head :forbidden
      return
    end

    users = Array.new
    @course.teachers.each do |user|
      if params["selector#{user.id}"]
        users << user
      end
    end
    @course.remove_teachers(users)

    render :partial => 'user', :collection => @course.teachers, :locals => { :cid => @course.id }
  end

  def gradings

    @exercises = Exercise.all(:include => [{:course_instance => [:course]}, :categories => [:sections => [:section_grading_options]]])

  end
end
