class CoursesController < ApplicationController
  before_filter :login_required #, :except => [:index, :show]
  
  # GET /courses
  def index
    if is_admin?(current_user)
      @courses = Course.find(:all)
      @allow_create = true
    else
      # TODO: show own courses
      @courses = Course.find(:all)
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
    
      flash[:success] = t(:course_created_flash)
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
      flash[:success] = t(:course_updated_flash)
      redirect_to(@course)
    else
      render :action => "edit"
    end
  end

  # DELETE /courses/1
  def destroy
    @course = Course.find(params[:id])
    
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
    
    name = @course.name
    if @course.destroy
      flash[:success] = t(:course_deleted_flash, :name => name)
    else
      flash[:error] = t(:course_delete_failed_flash, :name => name)
    end
    
    redirect_to(courses_url)
  end

  def teachers
    @course = Course.find(params[:id])
    
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
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

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    users = Array.new
    @course.teachers.each do |user|
      if params["selector#{user.id}"]
        users << user
      end
    end
    @course.remove_teachers(users)

    render :partial => 'user', :collection => @course.teachers, :locals => { :cid => @course.id }
  end
end
