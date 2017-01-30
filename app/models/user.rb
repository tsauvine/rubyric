class User < ActiveRecord::Base
  acts_as_authentic do |c|
    c.login_field = :email
    c.crypto_provider = Authlogic::CryptoProviders::SCrypt
    c.transition_from_crypto_providers = Authlogic::CryptoProviders::Sha512
    c.require_password_confirmation = false
    #c.validate_password_field = false
    #c.validate_email_field = false
    #c.transition_from_restful_authentication = true
  end

  validates :login, uniqueness: true, allow_nil: true
  validates :email, uniqueness: true

  # attr_accessible :firstname, :lastname, :email, :password, :password_confirmation

  belongs_to :organization

  has_many :orders

  has_many :group_members
  has_many :groups, through: :group_members
  #has_and_belongs_to_many :groups

  has_many :reviews # reviews as a grader
  has_many :review_ratings

  has_many :group_reviewers
  has_many :assigned_groups, through: :group_reviewers, source: :group

  # has_many :group_reviewers
  # has_many :groups_to_review, order: 'id', through: :group_reviewers

  # TODO: filter inactive courses
  has_and_belongs_to_many :course_instances_student, {class_name: 'CourseInstance', join_table: 'course_instances_students', order: :course_instance_id}
  has_and_belongs_to_many :course_instances_assistant, {class_name: 'CourseInstance', join_table: 'assistants_course_instances', order: :course_instance_id}
  has_and_belongs_to_many :courses_teacher, {class_name: 'Course', join_table: 'courses_teachers', order: :code}

  def require_password?
    new_record?
  end

  def knowledge=(new_knowledge)
    new_knowledge = JSON.parse(new_knowledge || '{}') if new_knowledge.is_a? String
    current_knowledge = JSON.parse(read_attribute(:knowledge) || '{}')

    logger.debug("current_knowledge: #{current_knowledge}")
    logger.debug("new_knowledge: #{new_knowledge}")

    write_attribute(:knowledge, current_knowledge.merge!(new_knowledge))
  end

  def get_pricing
    if self.course_count < 1
      return PricingFree.new
    else
      return PricingA.new
    end
  end

  def name
    if firstname.blank? && lastname.blank?
      email
    else
      "#{firstname} #{lastname}"
    end
  end

  def admin?
    self.admin
  end

  def teacher?
    courses_teacher.size > 0
  end

  def deliver_password_reset_instructions
    reset_perishable_token!
    PasswordMailer.delay.password_reset_instructions(self.id)
  end

  # Calculates the number of peer reviews created and finished in a certain exercise.
  # Warning: queries the database.
  # Returns
  # {
  #   created_peer_reviews: integer,
  #   finished_peer_reviews: integer
  # }
  def peer_review_count(exercise)
    created_peer_reviews = 0
    finished_peer_reviews = 0

    Review.joins(:submission).where(user_id: id, 'submissions.exercise_id' => exercise.id).find_each do |peer_review|
      created_peer_reviews += 1
      finished_peer_reviews += 1 if %w(finished mailed mailing invalidated).include? peer_review.status
    end

    return {
        created_peer_reviews: created_peer_reviews,
        finished_peer_reviews: finished_peer_reviews
    }
  end
end
