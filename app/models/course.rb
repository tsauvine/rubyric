class Course < ActiveRecord::Base
  has_many :course_instances, dependent: :destroy
  has_many :active_instances, dependent: :destroy, class_name: 'CourseInstance'
  belongs_to :organization

  has_and_belongs_to_many :teachers, {class_name: 'User', join_table: 'courses_teachers', order: :studentnumber}

  validates_presence_of :name

  def full_name
    if self.code.blank?
      self.name
    else
      "#{self.code} #{self.name}"
    end
  end

  def has_teacher(user)
    user && teachers.include?(user)
  end

  # Removes teachers from the course. The parameter can be
  # an array of user ids or an array of user objects.
  # Returns the number of users removed
  def remove_teachers(users)
    counter = 0

    users.each do |user|
      counter += remove_teacher(user)
    end

    return counter
  end

  # Removes a teacher from the course instance. The parameter can be
  # a user id or a user object
  def remove_teacher(user)
    user = User.find(user) unless user.is_a?(User)
    teachers.delete(user)
    return 1

    rescue
      return 0
  end

  def email
    address = read_attribute(:email)

    if !address.blank?
      return address
    elsif teachers.size > 0
      return teachers.first.email
    else
      return ''
    end
  end

    # Creates an example course, instance and submissions.
  def self.create_example(teacher)
    example_submission_filename = "#{SUBMISSIONS_PATH}/example.pdf"
    exists = File.exists?(example_submission_filename)

    course = Course.new(:name => 'Example course')
    course.organization_id = teacher.organization_id if teacher
    course.save(:validate => false)

    course.teachers << teacher if teacher

    instance = CourseInstance.new(:course_id => course.id, :name => Time.now.year, :submission_policy => 'unauthenticated')
    instance.pricing = PricingFree.create
    instance.save(:validate => false)
    t = Time.now + 2.months
    deadline = Time.mktime(t.year, t.month, t.day)
    exercise = Exercise.new(
      :course_instance_id => instance.id,
      :name => 'Assignment 1',
      :deadline => deadline,
      :groupsizemax => 3,
      :review_mode => 'annotation'
    )
    exercise.initialize_example_rubric
    exercise.save(:validate => false)

    # FIXME: makedirs may throw an exception
    submission_path = "#{SUBMISSIONS_PATH}/#{exercise.id}"
    FileUtils.makedirs(submission_path)

    # Create groups and submissions
    instance.create_example_groups(10)
    exercise.create_example_submissions

    return exercise
  end
end
