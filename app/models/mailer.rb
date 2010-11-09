class Mailer < ActionMailer::Base

  # Sends the review by email to the students
  def review(review)
    exercise = review.submission.exercise
    course_instance = exercise.course_instance
    course = course_instance.course

    @subject = "#{course.code} #{course.name} - #{exercise.name}"
    @sent_on = Time.now

    unless exercise.anonymous_graders
      grader = review.user
      @body['grader'] = grader
      @from = grader.email
    else
      @from = course.email
    end
    # @headers = {"Reply-to" => course.email}

    # Collect receiver addresses
    recipients = Array.new
    review.submission.group.users.each do |user|
      if user.email.blank?
        recipients << "#{user.studentnumber}@students.hut.fi"
      else
        recipients << user.email
      end

      # recipients << user.email unless user.email.blank?
    end

    @recipients = recipients.join(",")

    @body['review'] = review
    @body['course'] = course
    @body['course_instance'] = course_instance
    @body['exercise'] = exercise

    # Set status
    review.status = 'mailed'
    review.save
  end

  # Sends a "you have been assigned" message
  def assignment(review)
    exercise = review.submission.exercise
    course_instance = exercise.course_instance
    course = course_instance.course

    @subject = "#{course.code} #{course.name} - #{exercise.name}"
    @sent_on = Time.now
    @from = course.email
    @recipients = review.user.email

    @body['review'] = review
    @body['submission'] = review.submission
    @body['course'] = course
    @body['course_instance'] = course_instance
    @body['exercise'] = exercise
  end

end
