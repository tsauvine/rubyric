class CourseInstancesController < ApplicationController
  before_filter :login_required

  # GET /course_instances/1
  def show
    @course_instance = CourseInstance.find(params[:id])
    load_course

    @allow_edit = @course.has_teacher(current_user) || is_admin?(current_user)
    
    log "view_course_instance #{@course_instance.id}"
  end

  # GET /course_instances/new
  # GET /course_instances/new.xml
  def new
    # Load course
    if params[:course_id]
      @course = Course.find(params[:course_id])
      
      # Authorize
      return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
      
      load_course
    else
      @course = Course.new
    end

    @course_instance = CourseInstance.new(:submission_policy => 'authenticated') # :name => Time.now.year
    
    render :action => 'new', :layout => 'narrow-new'
    log "create_course_instance #{@course.id}"
  end

  # GET /course_instances/1/edit
  def edit
    @course_instance = CourseInstance.find(params[:id])
    load_course

    # Authorize
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
    
    log "edit_course_instance #{@course_instance.id}"
  end

  # POST /course_instances
  # POST /course_instances.xml
  def create
    @course_instance = CourseInstance.new(params[:course_instance])
    course_instance_valid = @course_instance.valid?
    
    if params[:course_id]
      @course = Course.find(params[:course_id])
      @course_instance.course_id = @course.id
      return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
      course_valid = true
    else
      @course = Course.new(:name => params[:course_name])
      course_valid = @course.valid?
    end

    if course_valid && course_instance_valid
      if @course.new_record?
        @course.organization_id = current_user.organization_id
        @course.teachers << current_user
        @course.save
      end
      
      @course_instance.course_id = @course.id
      @course_instance.save
    
      redirect_to @course_instance
      log "create_course_instance success #{@course_instance.id}"
    else
      render :action => 'new', :layout => 'narrow-new'
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
      log "edit_course_instance success #{@course_instance.id}"
    else
      render :action => "edit"
      log "edit_course_instance fail #{@course_instance.id} #{@course_instance.errors.full_messages.join('. ')}"
    end
  end

  # DELETE /course_instances/1
  def destroy
    @course_instance = CourseInstance.find(params[:id])
    load_course

    # Authorize
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
    log "delete_course_instance #{@course_instance.id}"

    #Destroy
    @course_instance.destroy
    redirect_to(@course)
  end


#   # Ajax action for uploading a csv student list
#   def students_csv
#     @course_instance = CourseInstance.find_by_id(params[:course_instance_id])
#     load_course
# 
#     return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
# 
#     if params[:paste]
#       @course_instance.add_students_csv(params[:paste])
#     end
# 
#     render :partial => 'user', :collection => @course_instance.students, :locals => { :iid => @course_instance.id }
#   end
# 
# 
#   # Ajax action for uploading a csv stundent list
#   def add_assistants_csv
#     @course_instance = CourseInstance.find_by_id(params[:course_instance_id])
#     load_course
# 
#     return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
# 
#     if params[:paste]
#       @course_instance.add_assistants_csv(params[:paste])
#     end
# 
#     render :partial => 'user', :collection => @course_instance.assistants, :locals => { :iid => @course_instance.id }
#   end
# 

  
  def create_example_groups
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course
    authorize! :update, @course_instance
    
    @course_instance.create_example_groups
    
    redirect_to @course_instance
    log "create_example_groups #{@course_instance.id}"
  end
  
  def send_feedback_bundle
    @course_instance = CourseInstance.find(params[:course_instance_id])
    authorize! :update, @course_instance
    
    Review.delay.deliver_bundled_reviews(@course_instance.id)
    flash[:success] = 'Sending feedback mails'
    
    redirect_to @course_instance
    log "send_feedback_bundle #{@course_instance.id}"
  end
  
end
