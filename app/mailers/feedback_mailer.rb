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

    if @course.email.blank?
      from = @grader.email
    else
      from = @course.email
      #headers["Reply-to"] = @grader.email
    end
    #unless @exercise.anonymous_graders
    #end

    # Collect receiver addresses
    recipients = []
    review.submission.group.users.each do |user|
      recipients << user.email unless user.email.blank?
    end
    
    if recipients.empty?
      # TODO: raise an exception with an informative message
      review.status = 'finished'
      review.save
      return
    end
    
    # Attachment
    unless @review.filename.blank?
      attachments[@review.filename] = File.read(@review.full_filename)
    end
    
    subject = "#{@course.code} #{@course.name} - #{@exercise.name}"
    
    I18n.with_locale(@course_instance.locale || I18n.locale) do
      mail(:to => recipients.join(","), :from => from, :subject => subject)
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
