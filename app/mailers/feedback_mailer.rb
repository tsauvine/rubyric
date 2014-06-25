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
    group = review.submission.group

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
    group.group_members.each do |member|
      if member.user
        recipients << member.user.email unless member.user.email.blank?
      else
        recipients << member.email unless member.email.blank?
      end
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
    
    subject = "#{@course.full_name} - #{@exercise.name}"
    
    if review.type == 'AnnotationAssessment'
      template_name = 'annotation'
      @review_url = review_url(review.id, :group_token => group.access_token, :protocol => 'https://')
    else
      template_name = 'review'
    end
    
    I18n.with_locale(@course_instance.locale || I18n.locale) do
      mail(
        :to => recipients.join(","),
        :reply_to => from,
        :subject => subject,
        :template_path => 'feedback_mailer',
        :template_name => template_name
      )
    end

    # Set status
    review.status = 'mailed'
    review.save
  end
  
  def bundled_reviews(course_instance, user, reviews, exercise_grades)
    return if user.email.blank?
    
    @reviews = reviews
    @exercise_grades = exercise_grades
    @course_instance = course_instance
    @course = @course_instance.course
    
    from = @course.email 
    from = RUBYRIC_EMAIL if from.blank?
    
    subject = "#{@course.full_name}"
    
    # Attachments
    @reviews.each do |review|
      attachments[review.filename] = File.read(review.full_filename) unless review.filename.blank?
    end
    
    I18n.with_locale(@course_instance.locale || I18n.locale) do
      mail(
        :to => user.email, :from => from, :subject => subject
      )
    end
  end
  
  def delivery_errors(errors)
    @errors = errors
    mail(:to => ERRORS_EMAIL, :subject => '[Rubyric] Undelivered feedback mails')
  end
  
end
