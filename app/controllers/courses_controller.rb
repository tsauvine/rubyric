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
    
    log "courses index"
  end

  # GET /courses/1
  def show
    @course = Course.find(params[:id])
    @is_teacher = @course.has_teacher(current_user) || is_admin?(current_user)
    
    log "view_course #{@course.id}"
  end

  # GET /courses/new
  # GET /courses/new.xml
  def new
    @course = Course.new
    @course_instance = CourseInstance.new
    
    render :action => 'new', :layout => 'narrow-new'
    log "create_course"
  end

  # GET /courses/1/edit
  def edit
    @course = Course.find(params[:id])
    @is_teacher = @course.has_teacher(current_user) || is_admin?(current_user)

    return access_denied unless @is_teacher
    
    log "edit_course #{@course.id}"
  end

  # POST /courses
  def create
    @course = Course.new(params[:course])
    @course.organization_id = current_user.organization_id

    if @course.save
      @course.teachers << current_user

      flash[:success] = t(:course_created_flash)
      redirect_to new_course_course_instance_path(:course_id => @course.id)
      log "create_course success #{@course.id}"
    else
      render :action => 'new', :layout => 'narrow-new'
      log "create_course fail #{@course.errors.full_messages.join('. ')}"
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
      log "edit_course success #{@course.id}"
    else
      render :action => "edit"
      log "edit_course fail #{@course.id} #{@course.errors.full_messages.join('. ')}"
    end
  end

  # DELETE /courses/1
  def destroy
    @course = Course.find(params[:id])

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    log "delete_course #{@course.id}"
    name = @course.name
    if @course.destroy
      flash[:success] = t(:course_deleted_flash, :name => name)
    else
      flash[:error] = t(:course_delete_failed_flash, :name => name)
    end

    redirect_to(courses_url)
  end

#   def teachers
#     @course = Course.find(params[:id])
# 
#     return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
#   end
# 
#   # Ajax action for deleting multiple teachers
#   def remove_selected_teachers
#     @course = Course.find(params[:course_id])
# 
#     return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
# 
#     users = Array.new
#     @course.teachers.each do |user|
#       if params["selector#{user.id}"]
#         users << user
#       end
#     end
#     @course.remove_teachers(users)
# 
#     render :partial => 'user', :collection => @course.teachers, :locals => { :cid => @course.id }
#   end
end
