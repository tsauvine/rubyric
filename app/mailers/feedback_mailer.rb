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
    group = submission.group
    subject = "#{@course.full_name} - #{@exercise.name}"
    
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
      combined_grade = combined_grade / grade_count
    end
    
#     recipients = []
#     group.group_members.each do |member|
#       if !member.email.blank?
#         recipients << member.email
#       elsif member.user && !member.user.email.blank?
#         recipients << member.user.email
#       end
#     end
    
    # Koodiaapinen hack Spring 2016 (Note: does not work correctly for group work)
    # Don't send feedback if the student has not conducted peer reviews
    # Convert points to pass/fail
    if @exercise.id == 218 || @exercise.id == 235
      if combined_grade >= 4.99
        combined_grade = max_grade
      else
        combined_grade = 0
      end
      
      # Count reviews conducted by the user
      valid_submission_ids = @exercise.submission_ids
      max_review_count = 0
      
      File.open('peer_reviews.txt', 'a') do |file|
        group.users.each do |student|
          finished_review_count = 0
          started_review_count = 0
          Review.where(:user_id => student.id).find_each do |review|
            next unless valid_submission_ids.include?(review.submission_id)
            finished_review_count += 1 if ['finished', 'mailing', 'mailed', 'invalidated'].include?(review.status)
            started_review_count += 1 if ['started'].include?(review.status) || review.status.blank?
          end
          
          total_review_count = finished_review_count + started_review_count
          max_review_count = total_review_count if total_review_count > max_review_count
          
          file.puts "#{max_review_count},#{finished_review_count} #{group.users.first.firstname} #{group.users.first.lastname}"
        end
      end
      
      if max_review_count < @exercise.peer_review_goal
        Review.where(:id => review_ids, :status => 'mailing').update_all(:status => 'finished')
        return
      end
    end
    
#     Review.where(:id => review_ids, :status => 'mailing').update_all(:status => 'mailed')
#     return
    
    I18n.with_locale(@course_instance.locale || I18n.locale) do
      feedback = render_to_string(action: :aplus).to_str
    
#       mail(
#         :to => recipients.join(","),
#         :subject => subject,
#         :template_path => 'feedback_mailer',
#         :template_name => 'aplus'
#       )
    end
    
    success = false
    if submission.aplus_feedback_url.blank?
      puts "MAX GRADE: #{max_grade}"
      # Generate JSON for manual transfer
      object = {
        "students_by_email" => submission.group.group_members.map {|member| member.email },
        "feedback" => feedback,
        "grader" => 'grader_placeholder',
        "exercise_id" => 'exercise_id_placeholder',
        "submission_time" => submission.created_at,
        "points" => (10 * combined_grade / max_grade).round
      }
      
      File.open('aplus_grades.json', 'a') do |file|
        file.print object.to_json
        file.puts ','
      end
      
      success = true
    else
      if Rails.env == 'production'
        response = RestClient.post(submission.aplus_feedback_url, {points: combined_grade.round, max_points: max_grade.round, feedback: feedback})
        
        success = true if response.code == 200
      else
        logger.debug "Skipping A+ API call in development environment. #{submission.aplus_feedback_url}, points: #{combined_grade.round}, max_points: #{max_grade.round}"
      end
    end
    
    if success
      Review.where(:id => review_ids, :status => 'mailing').update_all(:status => 'mailed')
    else
      logger.error "Failed to submit points to A+"
      logger.error response
    end
  end

  def submission_received(submission_id)
    @submission = Submission.find(submission_id)
    @group = @submission.group
    @exercise = @submission.exercise
    @course_instance = @exercise.course_instance
    @course = @course_instance.course
    
    subject = "#{@course.full_name} - #{@exercise.name}"
    
    # FIXME: repetition, see review()
    recipients = []
    @group.group_members.each do |member|
      if !member.email.blank?
        recipients << member.email
      elsif member.user && !member.user.email.blank?
        recipients << member.user.email
      end
    end
    
    I18n.with_locale(@course_instance.locale || I18n.locale) do
      mail(
        :to => recipients.join(","),
        :subject => subject
      )
    end
    
  end
  
end
