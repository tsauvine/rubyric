class FeedbackMailer < ActionMailer::Base
  default :from => RUBYRIC_EMAIL
  
  # Sends the review by email to the students
  def review(review)
    @review = review
    @exercise = @review.submission.exercise
    @course_instance = @exercise.course_instance
    @course = @course_instance.course

    @exercise.anonymous_graders = true
    unless @exercise.anonymous_graders
      @grader = @review.user
    #  from = grader.email
    else
      from = @course.email
    end
    # @headers = {"Reply-to" => course.email}

    # Collect receiver addresses
    recipients = []
    @review.submission.group.users.each do |user|
      recipients << user.email unless user.email.blank?
    end
    recipients = recipients.join(",")
    
    subject = "#{@course.code} #{@course.name} - #{@exercise.name}"
    
    mail(:to => recipients, :from => from, :subject => subject)

    # Set status
    review.status = 'mailed'
    review.save
  end
end
