class Review < ActiveRecord::Base
  belongs_to :submission
  belongs_to :user        # grader

  has_many :feedbacks, :dependent => :destroy

  after_create :create_feedbacks


  # status: [empty], started, unfinished, finished, mailed

  # Creates a feedback object for each section
  def create_feedbacks
    submission.exercise.categories.each do |category|
      category.sections.each do |section|
        feedback = Feedback.new
        feedback.section_id = section.id
        feedback.review_id = id
        feedback.save
      end
    end
  end

  # Returns the feedback object corresponding the section in question.
  # A new feedback object is created and saved automatically, if it didn't previously exist.
  def find_feedback(section_id)
    self.feedbacks.each do |feedback|
      return feedback if feedback.section_id == section_id
    end

    # Feedback wasn't found. This means that someone has altered the rubric. Create a new feedback object.
    feedback = Feedback.new
    feedback.section_id = section_id  # TODO: Check that this section belongs to the exercise
    feedback.review_id = id
    self.feedbacks << feedback

    return feedback
  end

  # Returns true if all section feedbacks are finished
  def sections_finished?
    self.feedbacks.each do |feedback|
      return false if feedback.status != 'finished'
    end

    return true
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
    case submission.exercise.feedbackgrouping
      when 'sections'
        self.feedback = collect_feedback_sections
      when 'categories'
        self.feedback = collect_feedback_categories
      else
        self.feedback = collect_feedback_exercise
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

end
