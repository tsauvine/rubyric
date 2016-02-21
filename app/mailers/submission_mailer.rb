class SubmissionMailer < ActionMailer::Base
  def receive(email)
    logger.info "Receiving mail from #{email.from} to #{email.to}, subject #{email.subject}"
    
    # Find exercise by 'to' address
    begin
      email.to.each do |address|
        to_parts = address.split('@')
        logger.info "Email submission to (#{to_parts[0]})"
        exercise_id = Integer(to_parts[0])
        @exercise = Exercise.where(:id => exercise_id).first
        break if @exercise
      end
    rescue
      logger.warn("Cannot find exercise (#{email.to})")
      return
    end
    logger.info "Found exercise #{@exercise.id}"
    
    # Find user by email
    @user = User.find_by_email(email.from.first)
    
    # Create group
    @group = Group.new(:min_size => @exercise.groupsizemin, :max_size => @exercise.groupsizemax, :course_instance => @exercise.course_instance, :exercise => @exercise)
    @group_members = []
    
    email.from.each do |address|
      address.strip!
      next if address.blank?
      
      member = GroupMember.new(:email => address)
      logger.info "Adding group member #{address}"
      member.group = @group
      
      member.user = @user if @user && member.email == @user.email
      
      @group_members << member
    end

    @group.group_members = @group_members
    
    unless @group.save
      logger.error "Failed to greate group. #{@group.errors.full_messages.join('. ')}"
      return
    end
    
    if email.has_attachments?
      email.attachments.each do |attachment|
        logger.info "Attachment:"
        #logger.info attachment
        
        submission = Submission.new(:exercise => @exercise, :group => @group)
        submission.payload = email.body
        submission.file = attachment
        submission.save
      end
    else
      logger.info "No attachment"
      
      # Create a submission and put message body to payload
      t = Time.now
      submission = Submission.new(:exercise => @exercise, :group => @group)
      submission.payload = email.body
      submission.filename = "#{t.year}-#{t.month}-#{t.day}.txt"
      submission.extension = 'txt'
      submission.save
    end
  end
end
