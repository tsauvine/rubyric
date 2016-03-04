# encoding: UTF-8

class Review < ActiveRecord::Base
  belongs_to :submission
  belongs_to :user        # grader

  #has_many :feedbacks, :dependent => :destroy

  # status: [empty], started, unfinished, finished, mailing, mailed, invalidated

  def include_in_results?
    status == 'finished' || status == 'mailed' || status == 'mailing'
  end
  
  def update_from_json(id, json)
    review = Review.find(id)
    review.update_attributes(json)
  end
  
  # Saves the file to the filesystem.
  # This must be called after create, because we need to know the id.
  def write_file(file_data, exercise)
    return unless file_data
      
    # TODO: check if utf-8 will cause problems
    self.filename = file_data.original_filename
    self.extension = file_data.original_filename.split(".").last

    path = "#{FEEDBACK_PATH}/#{exercise.id}"
    filename = "#{self.id}.#{self.extension}"
    FileUtils.makedirs(path)

    File.open("#{path}/#{filename}", "wb") do |file|
      file.write(file_data.read)
    end
  end
  
  # Returns the location of the feedback file in the filesystem.
  def full_filename
    "#{FEEDBACK_PATH}/#{submission.exercise.id}/#{id}.#{extension}"
  end

  
  def calculate_grade
    categories_counter = 0
    category_points_counter = 0

    submission.exercise.categories.each do |category|
      # Sum section grades
      sections_counter = 0
      section_points_counter = 0
      category.sections.each do |section|
        feedback = Feedback.find(:first, :conditions => ["section_id = ? AND review_id = ?", section.id, self.id])
        next unless feedback

        if section.section_grading_options.size > 0 && feedback.section_grading_option
          section_points_counter += section.weight * feedback.section_grading_option.points
          sections_counter += section.weight
        end
      end

      case submission.exercise.grading_mode
        when "average"
          section_grade = (sections_counter == 0) ? 0 : section_points_counter / sections_counter
        else
          section_grade = section_points_counter
      end

      category_points_counter += category.weight * section_grade
      categories_counter += category.weight
    end


    case submission.exercise.grading_mode
      when "sum"
        grade = category_points_counter
      when "average"
        grade = (categories_counter == 0) ? 0 : category_points_counter / categories_counter
      else
        grade = nil
    end

    self.grade = grade.round unless grade.blank?    # Will be deprecated
    self.calculated_grade = grade.round unless grade.blank?
  end
  
  # Collects feedback texts from all sections and and combines them into the final feedback.
  # This destroys the existing final feedback.
  def collect_feedback
    rubric = JSON.parse(self.submission.exercise.rubric)
    review = JSON.parse(self.payload)
    
    # Load rubric
    rubric_pages = {}
    rubric['pages'].each do |page|
      rubric_pages[page['id']] = page
    end
    
    grading_mode = rubric['gradingMode']
    final_comment = rubric['finalComment']
    feedback_categories = rubric['feedbackCategories']

    # Prepare grading
    grade_index = {}           # grade_value => array index, for getting array index by grade value, for calculating average verbal grade
    numeric_grading = false    # Numerical or verbal grading
    no_grading = true          # Is there grading at all?
    if rubric['grades']
      no_grading = false if rubric['grades'].size > 0
      
      rubric['grades'].each_with_index do |raw_grade, index|
        numeric_grading = true if raw_grade.is_a?(Numeric)  # If there is at least one numerical grade, numerical grading is used
        
        grade_index[raw_grade] = index
      end
    end
  
    # Generate feedback text
    text = ''
    grade_sum = 0.0
    grade_index_sum = 0.0
    grade_counter = 0
    all_grades_set = true
    review['pages'].each do |feedback_page|
      rubric_page = rubric_pages[feedback_page['id']]
      
      text << "== #{rubric_page['name']} ==\n" if rubric_page['name']
      
      feedback = feedback_page['feedback'] || []
      grade = feedback_page['grade']

      unless feedback[0].blank?
        text << "\n= #{feedback_categories[0]} =\n" unless feedback_categories[0].blank?
        text << feedback[0]
      end

      unless feedback[1].blank?
        text << "\n= #{feedback_categories[1]} =\n" unless feedback_categories[1].blank?
        text << feedback[1]
      end

      unless feedback[2].blank?
        text << "\n= #{feedback_categories[2]} =\n" unless feedback_categories[2].blank?
        text << feedback[2]
      end
        
      text << "\n\n"
      
      if grade
        grade_index_sum += grade_index[grade]  # Calculate average index
        
        if grade.is_a?(Numeric) && grade_sum
          grade_sum += grade     # Calculate average value
        else
          grade_sum = false      # If a non-numeric grade value is encountered, average value cannot be calculated
        end
      else
        all_grades_set = false
      end
      
      grade_counter += 1
    end
    
    # Final comment
    text << final_comment if final_comment
    self.feedback = text
    
    
    # Calculate grade
    self.grade = nil

    grading_finished = all_grades_set || no_grading
    
    if grading_finished && !no_grading
      case grading_mode
      when 'average'
        
        if numeric_grading
          self.grade = (grade_sum / grade_counter).round if grade_sum && grade_counter > 0
        else
          avg_grade_index = (grade_index_sum / grade_counter).round
          
          self.grade = rubric['grades'][avg_grade_index]
        end
        
      when 'sum'
        self.grade = grade_sum
      end
      
      self.status = 'unfinished'
    else
      self.status = 'started'
    end
    
  end

  # Collects feedback from all sections and groups all positive feedback together, all neagtive feedback together, etc.
  # Section captions are not shown.
  # Returns a string.
  def collect_feedback_exercise
    text = ''
    good = ''
    bad = ''
    neutral = ''

    submission.exercise.categories.each do |category|
      category.sections.each do |section|
        feedback = Feedback.find(:first, :conditions => ["section_id = ? AND review_id = ?", section.id, self.id])
        next unless feedback

        good << feedback.good + "\n" unless feedback.good.blank?
        bad << feedback.bad + "\n" unless feedback.bad.blank?
        neutral << feedback.neutral + "\n" unless feedback.neutral.blank?
      end
    end

    text << "= #{submission.exercise.positive_caption} =\n" unless submission.exercise.positive_caption.blank? || good.blank?
    text << "#{good.chomp}\n\n" unless good.blank?
    text << "= #{submission.exercise.negative_caption} =\n" unless submission.exercise.negative_caption.blank? || bad.blank?
    text << "#{bad.chomp}\n\n" unless bad.blank?
    text << "= #{submission.exercise.neutral_caption} =\n" unless submission.exercise.neutral_caption.blank? || neutral.blank?
    text << "#{neutral.chomp}\n\n" unless neutral.blank?
    text << "\n#{submission.exercise.finalcomment}\n" unless submission.exercise.finalcomment.blank?

    return text
  end

  def collect_feedback_categories
    text = ''

    submission.exercise.categories.each do |category|
      text << "== #{category.name} ==============================\n\n"
      good = ''
      bad = ''
      neutral = ''

      category.sections.each do |section|
        feedback = Feedback.find(:first, :conditions => ["section_id = ? AND review_id = ?", section.id, self.id])
        next unless feedback

        good << feedback.good + "\n" unless feedback.good.blank?
        bad << feedback.bad + "\n" unless feedback.bad.blank?
        neutral << feedback.neutral + "\n" unless feedback.neutral.blank?
      end

      text << "= #{submission.exercise.positive_caption} =\n" unless submission.exercise.positive_caption.blank? || good.blank?
      text << "#{good.chomp}\n\n" unless good.blank?
      text << "= #{submission.exercise.negative_caption} =\n" unless submission.exercise.negative_caption.blank? || bad.blank?
      text << "#{bad.chomp}\n\n" unless bad.blank?
      text << "= #{submission.exercise.neutral_caption} =\n" unless submission.exercise.neutral_caption.blank? || neutral.blank?
      text << "#{neutral.chomp}\n\n" unless neutral.blank?
      text << "\n"
    end

    text << submission.exercise.finalcomment unless submission.exercise.finalcomment.blank?

    return text
  end

  def collect_feedback_sections
    text = ''

    submission.exercise.categories.each do |category|
      category.sections.each do |section|

        feedback = Feedback.find(:first, :conditions => ["section_id = ? AND review_id = ?", section.id, self.id])
        next unless feedback

        text << "== #{section.name} ==============================\n\n"
        text << "= #{submission.exercise.positive_caption} =\n" unless submission.exercise.positive_caption.blank? || feedback.good.blank?
        text << "#{feedback.good.chomp}\n\n" unless feedback.good.blank?
        text << "= #{submission.exercise.negative_caption} =\n" unless submission.exercise.negative_caption.blank? || feedback.bad.blank?
        text << "#{feedback.bad.chomp}\n\n" unless feedback.bad.blank?
        text << "= #{submission.exercise.neutral_caption} =\n" unless submission.exercise.neutral_caption.blank? || feedback.neutral.blank?
        text << "#{feedback.neutral.chomp}\n\n" unless feedback.neutral.blank?
        text << "\n"
      end
    end

    text << submission.exercise.finalcomment unless submission.exercise.finalcomment.blank?

    return text
  end
  
  
  
  def self.deliver_reviews(review_ids)
    errors = []
    aplus_reviews = {} # { Submission => [Review, Review, ...] }
    
    # TODO: only send reviews with status 'finished' or 'mailing'
    Review.where(:id => review_ids).find_each do |review|
      begin
        if review.submission.is_a?(AplusSubmission)
          # Bundle reviews that belong to the same AplusSubmission
          aplus_reviews[review.submission] ||= []
          aplus_reviews[review.submission] << review
        else
          FeedbackMailer.review(review).deliver
        end
      #rescue Net::SMTPFatalError => e
      rescue Exception => e
        logger.error e
        errors << e
        review.status = 'finished'
        review.save
      end
    end
    
    aplus_reviews.each do |submission, reviews|
      FeedbackMailer.aplus_feedback(submission, reviews)
    end
    
    # Send delivery errors to teacher
    FeedbackMailer.delivery_errors(errors).deliver unless errors.empty?
  end
  
  def self.deliver_bundled_reviews(course_instance_id)
    course_instance = CourseInstance.find(course_instance_id)
    
    users_by_id = {}
    reviews_by_userid = {}
    
    course_instance.groups.each do |group|
      group.users.each do |user|
        users_by_id[user.id] = user
      end
    end
    
    course_instance.exercises.each do |exercise|
      Review.where("status='finished' OR status='mailed'").where(:submission_id => exercise.submission_ids).includes(:submission => :group).find_each do |review|
        review.submission.group.user_ids.each do |user_id|
          reviews_by_userid[user_id] ||= []
          reviews_by_userid[user_id] << review
        end
      end
    end
    
    reviews_by_userid.each do |user_id, reviews|
      exercise_grades = {}
      reviews.each do |review|
        exercise_grades[review.submission.exercise_id] = review.grade
      end
      
      FeedbackMailer.bundled_reviews(course_instance, users_by_id[user_id], reviews, exercise_grades).deliver
      
      reviews.each do |review|
        review.status = 'mailed'
        review.save
      end
    end
  end
    
end
