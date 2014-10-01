class GroupsController < ApplicationController
  before_filter :login_required, :only => [:index]

  layout 'narrow'
#
#   def set_layout
#     case params[:embed]
#     when 'embed'
#       'embed'
#     else
#       'wide'
#     end
#   end

  # GET /groups
  def index
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    if @course.has_teacher(current_user)
      @available_groups = Group.find_by_course_instance(@course_instance.id).joins(:users)
    else
      @available_groups = Group.where('course_instance_id=? AND user_id=?', @course_instance.id, current_user.id).joins(:users).order(:name).all.select { |group| group.users.size <= @exercise.groupsizemax }
    end
  end

  # GET /groups/1
  # GET /groups/1.xml
#   def show
#     @group = Group.find(params[:id])
#   end

  def new
    @exercise = Exercise.find(params[:exercise_id])
    load_course
    I18n.locale = @course_instance.locale || I18n.locale
    @is_teacher = @course.has_teacher(current_user)

    return access_denied unless logged_in? || @course_instance.submission_policy == 'unauthenticated'

    @group = Group.new(:min_size => @exercise.groupsizemin, :max_size => @exercise.groupsizemax)
    @group_members = []

    # Add current user
    if logged_in? && !@is_teacher
      member = GroupMember.new(:email => current_user.email)
      member.user = current_user
      @group_members << member
    end

    # Create group member slots
    (@group.max_size - @group_members.size).times do |i|
      @group_members << GroupMember.new()
    end

    log "create_group view #{params[:exercise_id]}"
  end

  # GET /groups/1/edit
  def edit
    @group = Group.find(params[:id])

    if params[:exercise_id]
      @exercise = Exercise.find(params[:exercise_id])
      log "edit_group view exercise #{params[:exercise_id]}"
    elsif params[:course_instance_id]
      @course_instance = CourseInstance.find(params[:course_instance_id])
      log "edit_group view course_instance #{params[:course_instance_id]}"
    end
    load_course
    I18n.locale = @course_instance.locale || I18n.locale

    return access_denied unless group_membership_validated(@group) || (@course && @course.has_teacher(current_user))

    @group_members = @group.group_members.all
    @group_members.sort! { |a, b| b.user ? 1 : 0 }  # Authenticated users first

    # Add empty slots
    (@group.max_size - @group_members.size).times do |i|
      @group_members << GroupMember.new()
    end
  end

  # POST /groups
  def create
    @exercise = Exercise.find(params[:exercise_id])
    load_course
    I18n.locale = @course_instance.locale || I18n.locale
    @is_teacher = @course.has_teacher(current_user)

    return access_denied unless logged_in? || @course_instance.submission_policy == 'unauthenticated'

    @group = Group.new(:min_size => @exercise.groupsizemin, :max_size => @exercise.groupsizemax, :course_instance => @exercise.course_instance, :exercise => @exercise)
    @group_members = []
    
#     if logged_in? && !@is_teacher
#       member = GroupMember.new(:email => current_user.email)
#       member.user = current_user
#       @group_members << member
#     end

    # Read params
    params['email'].each do |member_id, address|
      address.strip!
      next if address.blank?
      
      member = GroupMember.new(:email => address)
      member.group = @group
      
      member.user = current_user if logged_in? && member.email == current_user.email
      
      @group_members << member
    end

    @group.group_members = @group_members
#     @group.name = (@group.users.collect { |user| user.studentnumber }).join('_')
    
    if @group.save
      #@group.add_members(@group_members, @exercise)
      #@group.save

      if current_user
        @course_instance.students << current_user unless @course_instance.students.include?(current_user)
        redirect_to submit_path(:exercise => @exercise.id, :group => @group.id)
      else
        redirect_to submit_path(:exercise => @exercise.id, :group_token => @group.access_token)
      end
      
      log "create_group success #{@group.id},#{@exercise.id}"
    else
      (@group.max_size - @group_members.size).times do |i|
        @group_members << GroupMember.new()
      end
      
      render :action => 'new'
      log "create_group fail #{@exercise.id} #{@group.errors.full_messages.join('. ')}"
    end
  end

  def update
    @group = Group.find(params[:id])
    @exercise = Exercise.find(params[:exercise_id])
    load_course
    I18n.locale = @course_instance.locale || I18n.locale
    
    return access_denied unless group_membership_validated(@group) || (@course && @course.has_teacher(current_user))
    
    # Read params
    @invalid_addresses = false
    @group_members = []
    members_to_delete = []
    members_to_add = []
    params['email'].each do |member_id, address|
      address.strip!
      member = @group.group_members.all.select{ |m| m.id == member_id.to_i }.first

      if member
        # Edit existing invitation
        if address.blank?
          # Delete invitation
          members_to_delete << member
        else
          member.email = address
          @invalid_addresses = true if member.email_changed? && !member.save
          @group_members << member
        end
      elsif !address.blank?
        # Enter new invitation
        member = GroupMember.new(:email => address)
        member.group = @group
        @invalid_addresses = true unless member.save
        members_to_add << member
        @group_members << member
      end
    end

    # Delete members
    unless members_to_delete.empty?
      # Remove all members?
      if @group.group_members.size + members_to_add.size - members_to_delete.size < 1
        if @group.submissions.empty?
          @group.delete
          redirect_to submit_path(:exercise => @exercise.id)
          flash[:success] = t('groups.edit.group_deleted')
          return
        else
          # Show warning
          flash[:error] = t('groups.edit.cannot_delete_all')
          @invalid_addresses = true
        end
      else
        members_to_delete.each do |member|
          member.delete
        end
      end
    end
    
    if @invalid_addresses
      
      (@group.max_size - @group_members.size).times do |i|
        @group_members << GroupMember.new()
      end
      
      render :action => 'edit'
    else
      redirect_to submit_path(:exercise => @exercise.id, :group => @group.id, :member_token => params[:member_token], :group_token => params[:group_token])
      log "edit_group success #{@group.id},#{@exercise.id}"
    end
  end

  # DELETE /groups/1
  # DELETE /groups/1.xml
  def destroy
    return access_denied unless is_admin?(current_user)

    @group = Group.find(params[:id])
    @group.destroy
    redirect_to(groups_url)
  end

end
