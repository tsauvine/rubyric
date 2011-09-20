class GroupsController < ApplicationController
  # before_filter :login_required

  layout 'wide'

  # GET /groups
#   def index
#     @groups = Group.find(:all)
#   end

  # GET /groups/1
  # GET /groups/1.xml
#   def show
#     @group = Group.find(params[:id])
#   end

  def new
    @exercise = Exercise.find(params[:exercise])
    load_course

    @is_teacher = @course.has_teacher(current_user)
    unless logged_in? || @exercise.submit_without_login
      redirect_to_login
      return
    end

    @group = Group.new

    # Prefill the form
    @studentnumber = Array.new
    @email = Array.new

    if current_user && !@is_teacher
      @studentnumber[0] = current_user.studentnumber
      @email[0] = current_user.email
    end
  end

  # GET /groups/1/edit
#   def edit
#     @group = Group.find(params[:id])
#
#     unless is_admin?(current_user) || @group.has_member?(current_user)
#       @heading = 'Unauthorized'
#       @message = 'Course instance not specified'
#       render :template => "shared/error"
#     end
#   end

  # POST /groups
  def create
    @exercise = Exercise.find(params[:exercise])

    unless logged_in? || @exercise.submit_without_login
      @heading = 'Unauthorized'
      render :template => "shared/error"
      return
    end

    # Read studentnumbers
    members = Array.new
    params[:studentnumber].each do |id, value|
      members << {:studentnumber => value, :email => params[:email][id]} unless value.empty?
    end

    if members.size < @exercise.groupsizemin
      flash[:error] = "There must be at least #{@exercise.groupsizemin} member#{@exercise.groupsizemin == 1 ? '' : 's'} in the group."
      redirect_to :action => "new", :exercise => params[:exercise]
      return
    end

    @group = Group.new(params[:group])

    # Automatic groupname
    @group.name = (members.collect do |user| "#{user[:studentnumber]}" end).join('_')

    if @group.save
      @group.add_members(members)
      redirect_to :controller => 'submissions', :action => 'new', :exercise => @group.exercise, :group => @group.id
    else
      flash[:error] = 'Failed to create group.'
      redirect_to :action => "new", :exercise => params[:exercise]
    end

  end

  # PUT /groups/1
  # PUT /groups/1.xml
#   def update
#     @group = Group.find(params[:id])
#
#     respond_to do |format|
#       if @group.update_attributes(params[:group])
#         flash[:notice] = 'Group was successfully updated.'
#         format.html { redirect_to(@group) }
#         format.xml  { head :ok }
#       else
#         format.html { render :action => "edit" }
#         format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
#       end
#     end
#   end

  # DELETE /groups/1
  # DELETE /groups/1.xml
  def destroy
    unless logged_in?
      redirect_to_login
      return
    end

    unless is_admin?(current_user)
      @heading = 'Unauthorized'
      render :template => "shared/error"
      return
    end

    @group = Group.find(params[:id])
    @group.destroy
    redirect_to(groups_url)

  end

  # Ajax studentnumber checker
  def check_studentnumber
    user = User.find_by_studentnumber(params[:studentnumber])

    if !params[:studentnumber].empty? && !user
      render(:update) do |page|
        page.replace_html 'helpBox', "Student #{params[:studentnumber]} is not registered. Make sure you didn't misspell."
        page.select('#helpBox').first.show
      end
    else
      render(:update) do |page|
        page.select('#helpBox').first.hide
      end
    end
  end

  # Ajax email checker
  def check_email
    logger.info("Studentnumber: #{params[:studentnumber]}, Email: #{params[:email]}")

    user = User.find_by_studentnumber(params[:studentnumber])

    if false && user && !params[:email].empty? && user.email != params[:email]
      render(:update) do |page|
        page.replace_html 'helpBox', "Email address of student #{params[:studentnumber]} does not match the one in our database. Please check that you didn't misspell."
        page.select('#helpBox').first.show
      end
    else
      render(:update) do |page|
        page.select('#helpBox').first.hide
      end
    end
  end
end
