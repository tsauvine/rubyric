class Group < ActiveRecord::Base
  belongs_to :exercise
  belongs_to :course_instance

  has_many :group_members, dependent: :destroy
  has_many :users, through: :group_members

  has_many :submissions, dependent: :destroy
  has_many :submission_summaries, class_name: 'Submission', dependent: :destroy

  has_many :group_reviewers, dependent: :destroy
  has_many :reviewers, through: :group_reviewers, source: :user, class_name: 'User'

  #accepts_nested_attributes_for :group_members, :reject_if => proc { |attributes| attributes['email'].blank? }
  validate :require_group_members
  before_create :generate_token

  attr_accessor :url # Needed for JSON serialization

  def name
    self.group_members.collect { |member| member.user ? member.user.name : member.email }.join(', ')
  end

  def names_with_studentnumbers
    self.group_members.collect do |member|
      if member.user
        if member.user.studentnumber.blank? && member.user.name.blank?
          if member.user.email.blank?
            member.email
          else
            member.user.email
          end
        else
          text = ''
          text << "#{member.user.name} " unless member.user.name.blank?
          text << "(#{member.user.studentnumber})" unless member.user.studentnumber.blank?
          text
        end
      else
        member.email
      end
    end.join(', ')
  end

  def require_group_members
    errors.add(:base, 'Group cannot be empty') if self.group_members.empty?
  end

  # Generates a unique token
  def generate_token
    begin
      self.access_token = Digest::SHA1.hexdigest([Time.now, rand].join)
    end while Group.exists?(access_token: self.access_token)
  end

  def has_member?(user)
    user && users.include?(user)
  end

  def has_reviewer?(user)
    user && reviewers.include?(user)
  end

  def add_member(user)
    return if self.users.include?(user)

    member = GroupMember.new(email: user.email, studentnumber: user.studentnumber)
    member.group = self
    member.user = user
    member.save(validate: false)

    self.course_instance.students << user unless self.course_instance.students.include?(user)
  end

  # members: array of GroupMembers
  def add_members(members, exercise)
    members.each do |member|
      user = User.find_by_email(member.email)

      if user
        member.user = user
        member.save
        self.course_instance.students << user unless self.course_instance.students.include?(user)
      else
        member.save
        GroupMember.delay.send_invitation(member.id, exercise.id)
      end
    end
  end

  def self.compare_by_name(a, b)
    # Try to find a member with a User and a name
    a_member = a.group_members.max_by { |member| member.user ? (member.user.lastname.blank? ? 1 : 2) : 0 }
    b_member = b.group_members.max_by { |member| member.user ? (member.user.lastname.blank? ? 1 : 2) : 0 }

    # Empty groups last
    return 1 if !a_member
    return -1 if !b_member

    a_user = a_member.user
    b_user = b_member.user
    a_name = a_user ? a_user.lastname : nil
    b_name = b_user ? b_user.lastname : nil
    a_name = nil if a_name == ''
    b_name = nil if b_name == ''

    # Sort by name if both have a name
    return a_user.lastname.downcase <=> b_user.lastname.downcase if a_user && b_user && a_name && b_name

    # Sort by email if neither has a name
    return (a_member.email || '').downcase <=> (b_member.email || '').downcase if !a_name && !b_name

    # If one has a name and the other doesn't, put those without a name last
    return 1 if !a_name
    return -1 if !b_name

    return 0
  end

  # exercise: Exercise or exercise_id
  # mode: :earliest or :latest
  def self.compare_by_submission_time(a, b, exercise, mode = :earliest)
    exercise_id = if exercise.is_a? Exercise
                    exercise.id
                  else
                    exercise
                  end

    a_extreme, b_extreme = [a, b].map do |group|
      extreme_submission = nil
      group.submissions.each do |submission|
        next if submission.exercise_id != exercise_id
        if mode == :earliest
          # TODO; handle ties
          extreme_submission = submission if !extreme_submission || submission.created_at < extreme_submission.created_at
        else
          extreme_submission = submission if !extreme_submission || submission.created_at > extreme_submission.created_at
        end
      end

      extreme_submission ? extreme_submission.created_at : nil
    end

    return 1 if !a_extreme
    return -1 if !b_extreme

    a_extreme <=> b_extreme
  end


  # exercise: Exercise or exercise_id
  # mode: :earliest or :latest
  def self.compare_by_submission_status(a, b, exercise)
    exercise_id = if exercise.is_a? Exercise
                    exercise.id
                  else
                    exercise
                  end

    a_extreme, b_extreme = [a, b].map do |group|
      extreme_status = nil
      group.submissions.each do |submission|
        next if submission.exercise_id != exercise_id

        submission.reviews.each do |review|
          # FIXME: compare by semantic value
          extreme_status = (review.status || '') if !extreme_status || (review.status || '') < (extreme_status || '')
        end
      end

      extreme_status || ''
    end

    # FIXME: compare by semantic value, e.g. :finished < :mailed
    a_extreme <=> b_extreme
  end

  # Returns the total result of this group to a specific exercise, considering all submissions and reviews.
  # Hint: eager load submissions and reviews to maximize performance (includes(:submissions => :reviews)).
  #
  # average - :mean / :median
  # n_best  - integer
  #
  # Returns
  # {
  #   grade: integer / float / String / nil,
  #   reviews: [Review, ...],  # all reviews that are included in grading
  #   not_enough_reviews: true / false or missing
  #   no_submissions: true / false or missing
  #   errors: [String, ...]
  # }
  def result(exercise, options)
    submission_count = 0
    average = (options['average'] || :mean).to_sym
    logger.debug "OPTIONS: #{options}"
    logger.debug "AVERAGE MODE: #{average}"
    n_best = options['n_best']
    reviews = []
    result = {
        :errors => []
      }

    # Collect the reviews that should be included in the results
    submissions.each do |submission|
      next unless submission.exercise_id == exercise.id

      submission_count += 1
      submission.reviews.each do |review|
        next unless review.include_in_results?

        reviews << review
      end
    end
    result[:reviews] = reviews

    # Sort reviews by grade, best first
    not_sortable = false
    begin
      reviews.sort! { |a, b| Review.compare_grades!(b.grade, a.grade) }
      #logger.debug "Reviews after sorting #{reviews.map {|review| review.grade}.join(', ')}"
    rescue
      not_sortable = true
      #logger.debug "Reviews not sortable: #{reviews.map {|review| review.grade}.join(', ')}"
    end

    # Take n best
    if n_best
      logger.debug "Taking #{n_best} reviews"
      if n_best.abs > reviews.size
        result[:not_enough_reviews] = true
        logger.debug "Not enough reviews"
      end

      if n_best > 0
        # N best
        reviews = reviews.slice(0, n_best)
      else
        # N worst
        reviews = reviews.slice(n_best, -n_best)
      end

      logger.debug "Reviews after slicing #{reviews.map {|review| review.grade}.join(', ')}"
    end

    # Cast grades into the most convenient types, e.g. 4.0 => 4
    cast_grades = reviews.map {|review| Review.cast_grade(review.grade)}

    # Calculate grade range (difference between extreme grades)
    result[:grade_range] = case reviews.size
    when 0
      nil
    when 1
      0
    else
      begin
        minmax = cast_grades.minmax
        minmax[1] - minmax[0]
      rescue
        nil
      end
    end

    # Calculate mean or median
    if submission_count == 0
      result[:no_submissions] = true
    elsif reviews.empty?
      result[:not_enough_reviews] = true
    elsif not_sortable && (average == :median || average == :mix || average == :max)
      result[:errors] << 'Cannot calculate grade from non-numeric grades.'
    elsif average == :median
      result[:grade] = reviews[reviews.size / 2].grade
      # Even number or reviews:
      # if reviews.size % 2 == 0
      #  (reviews[reviews.size / 2 - 1].grade + reviews[reviews.size / 2].grade) / 2
    elsif average == :max
      result[:grade] = reviews.first.grade
    elsif average == :min
      result[:grade] = reviews.last.grade
    elsif average == :mean
      begin
        if reviews.size == 1
          # Non-numeric grades can be handled in this special case
          result[:grade] = reviews.first.grade
        else
          mean = cast_grades.inject(0.0){ |sum, grade| sum + grade }.to_f / reviews.size
          result[:grade] = mean.to_s
        end
      rescue Exception => e
        result[:errors] << 'Cannot calculate grade from non-numeric grades.'
      end
    else
      raise ArgumentError.new("Unrecognized average mode: #{average}")
    end

    return result
  end
end
