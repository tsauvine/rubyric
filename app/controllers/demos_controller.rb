class DemosController < ApplicationController

  layout 'demo'

  def rubric
    @exercise = Exercise.new
    @exercise.initialize_example_rubric
    log "demo_rubric"
  end

  def annotation
    @review = Review.new
    @exercise = Exercise.new
    @exercise.initialize_example_rubric
    @submission = ExampleSubmission.new
    log "demo_annotation"
  end

  def review
    @review = Review.new
    @exercise = Exercise.new
    @exercise.initialize_example_rubric
    @submission = ExampleSubmission.new
    user1 = User.new(:firstname => 'Student', :lastname => '1', :email => 'student1@example.com')
    user2 = User.new(:firstname => 'Student', :lastname => '2', :email => 'student2@example.com')
    user1.studentnumber = '12345'
    user2.studentnumber = '98765'
    member1 = GroupMember.new()
    member2 = GroupMember.new()
    member1.user = user1
    member2.user = user2
    @submission.group = Group.new
    @submission.group.group_members << [member1, member2]
    log "demo_review"
  end

  def submission
    respond_to do |format|
      format.html do
        send_file ExampleSubmission.new.full_filename, :type => 'application/pdf', :filename => 'example.pdf'
      end
      format.png do
        response.headers["Expires"] = 1.year.from_now.httpdate
        bitmap_info = ExampleSubmission.new.image_path(params[:page], params[:zoom])
        send_file bitmap_info[:path], :filename => bitmap_info[:filename], :type => bitmap_info[:mimetype], :disposition => 'inline'
      end
    end
  end
end
