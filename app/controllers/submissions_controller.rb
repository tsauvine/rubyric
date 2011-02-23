class SubmissionsController < ApplicationController
  before_filter :login_required, :only => [:show]
  
  layout 'wide'

  def show
    @submission = Submission.find(params[:id])
    @exercise = @submission.exercise
    load_course

    return access_denied unless @submission.group.has_member?(current_user) || @course_instance.has_assistant(current_user) || @course.has_teacher(current_user) || is_admin?(current_user)

    # logger.info("mime type: #{Mime::Type.lookup_by_extension(@submission.extension)}")

    unless File.exist?(@submission.full_filename)
      @heading = 'File not found'
      render :template => "shared/error"
    else
      if @submission.filename
        filename = @submission.filename
      else
        filename = "#{@submission.id}.#{@submission.extension}"
      end

      type = Mime::Type.lookup_by_extension(@submission.extension)
      
      send_file @submission.full_filename, :type => Mime::Type.lookup_by_extension(@submission.extension) || 'application/octet-stream', :filename => filename
    end
  end

  # GET /submissions/new
  def new
    @exercise = Exercise.find(params[:exercise]);
    load_course

    @user = current_user

    # Authorization
    return access_denied unless @user || @exercise.submit_without_login

    # Check that instance is open
    unless @course_instance.active
      render :action => 'instance_inactive'
      return
    end

    # Find group
    if !params[:group].blank?
      @group = Group.find(params[:group])
      # TODO: authorization
    elsif @user
      @group = Group.find(:first, :conditions => ['exercise_id=? AND user_id=?', @exercise.id, @user.id], :joins => :users)
    end

    unless @group
      if (@exercise.groupsizemax <= 1 && @user)
        # Create a group automatically
        @group = Group.new({:exercise_id => @exercise.id, :name => @user.studentnumber})
        @group.save
        @group.users << @user

        # Add user to the course
        @course_instance.students << @user unless @course_instance.students.include?(@user)
      else
        # Redirect to group creation
        redirect_to new_group_url(:exercise => @exercise.id)
        return
      end
    end

    @submission = Submission.new
  end

  def create
    @submission = Submission.new(params[:submission])
    @exercise = @submission.exercise
    load_course

    unless logged_in? || @exercise.submit_without_login
      @heading = 'Unauthorized'
      render :template => "shared/error"
      return
    end
    
    # Check that instance is open
    unless @course_instance.active
      flash[:error] = 'Submission rejected. Course instance is not active.'
      redirect_to submit_url(@exercise.id)
      return
    end

    # Check the file
    file = params[:file]

    if file.blank?
      flash[:error] = 'You must submit a file'
      redirect_to submit_url(@exercise.id)
      return
    else
      @submission.file = file
    end

    if @submission.save
      render :action => 'thanks'
    else
      flash[:error] = 'Failed'
      redirect_to submit_path(:exercise => params[:submission][:exercise_id])
    end

    # Auto assign
    if @exercise.autoassign
      @submission.group.submissions.each do |submission|
        # Take the first submission that has been assigned to somebody
        old_review = submission.reviews.first
        unless old_review.nil?
          new_review = @submission.assign_to(old_review.user)
          Mailer.deliver_assignment(new_review)
          break
        end
      end
    end
  end

end
