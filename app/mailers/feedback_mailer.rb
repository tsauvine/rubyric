class FeedbackMailer < ActionMailer::Base
  default :from => RUBYRIC_EMAIL
  default_url_options[:host] = RUBYRIC_HOST
  
  # Sends the review by email to the students
  def review(review)
    @review = review
    @exercise = @review.submission.exercise
    @course_instance = @exercise.course_instance
    @course = @course_instance.course
    @grader = @review.user

    from = @course.email
#     unless @exercise.anonymous_graders
#       from = @grader.email
#     end
    # @headers = {"Reply-to" => course.email}

    # Collect receiver addresses
    recipients = []
    @review.submission.group.users.each do |user|
      recipients << user.email unless user.email.blank?
    end
    recipients = recipients.join(",")
    
    subject = "#{@course.code} #{@course.name} - #{@exercise.name}"
    
    I18n.with_locale(@course_instance.locale || I18n.locale) do
      mail(:to => recipients, :from => from, :subject => subject)
    end

    # Set status
    review.status = 'mailed'
    review.save
  end
  
  def delivery_errors(errors)
    @errors = errors
    mail(:to => ERRORS_EMAIL, :subject => '[Rubyric] Undelivered feedback mails')
  end
  
end
