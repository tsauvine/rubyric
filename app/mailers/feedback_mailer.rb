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

    if !@course.email.blank?
      headers["Reply-to"] = @course.email
    elsif !@exercise.anonymous_graders && @grader
      headers["Reply-to"] = @grader.email
    end

    # Collect receiver addresses
    recipients = []
    group.group_members.each do |member|
      if !member.email.blank?
        recipients << member.email
      elsif member.user && !member.user.email.blank?
        recipients << member.user.email
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
        :subject => subject,
        :template_path => 'feedback_mailer',
        :template_name => template_name
      )
      #:reply_to => from,
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
  
  # Sends grades and feedback to A+
  def aplus_feedback(submission, reviews = [])
    @reviews = reviews
    @exercise = submission.exercise
    @course_instance = @exercise.course_instance
    @course = @course_instance.course
    
    combined_grade = 0.0
    grade_count = 0
    max_grade = @exercise.max_grade
    feedback = ''
    review_ids = []
    
    reviews.each_with_index do |review, index|
      review_ids << review.id
      #feedback << "<h1>Review #{index + 1}</h1>\n<pre>#{review.feedback}</pre>\n"
      
      begin
        combined_grade += Float(review.grade)
        grade_count += 1
      rescue ArgumentError => e
      rescue TypeError => e
      end
    end
    
    if max_grade.nil?
      max_grade = 1
      combined_grade = 1
    elsif grade_count == 0
      combined_grade = 0
    else
      combined_grade = (combined_grade / grade_count).round
    end
    
    I18n.with_locale(@course_instance.locale || I18n.locale) do
      feedback = render_to_string(action: :aplus).to_str
    end
    
    logger.info "Submission #{submission.id} (#{submission.aplus_feedback_url})\n#{{points: combined_grade, max_points: max_grade.round, feedback: feedback}}"
    response = RestClient.post(submission.aplus_feedback_url, {points: combined_grade, max_points: max_grade, feedback: feedback})
    
    if response.code == 200
      Review.where(:id => review_ids, :status => 'mailing').update_all(:status => 'mailed')
    else
      logger.error "Failed to submit points to A+"
      logger.error response
    end
  end

end
