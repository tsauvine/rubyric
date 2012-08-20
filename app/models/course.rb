class Course < ActiveRecord::Base
  has_many :course_instances, {:order => :id, :dependent => :destroy}
  has_many :active_instances, {:order => :id, :dependent => :destroy, :class_name => 'CourseInstance', :conditions => {:active => true}}

  has_and_belongs_to_many :teachers, {:class_name => 'User', :join_table => 'courses_teachers', :order => :studentnumber}

  validates_presence_of :code
  validates_presence_of :name

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
    example_submission_file = "#{SUBMISSIONS_PATH}/example.pdf"

    course = Course.create(:code => '0.123', :name => 'Example course')
    course.teachers << teacher if teacher

    instance = CourseInstance.create(:course_id => course.id, :name => 'Fall 2012')
    exercise = Exercise.create(
      :course_instance_id => instance.id,
      :name => 'Exercise 1',
      :deadline => Time.now + 1.year,
      :groupsizemax => 3,
      :positive_caption => 'Strengths',
      :negative_caption => 'Weaknesses',
      :neutral_caption => 'Other comments'
    )
    submission_path = "#{SUBMISSIONS_PATH}/#{exercise.id}"
    FileUtils.makedirs(submission_path)

    # Create groups and submissions
    group1 = Group.create(:exercise_id => exercise.id, :name => 'Group 1')
    group1.users << User.find_by_studentnumber('123456')
    submission1 = Submission.create(:exercise_id => exercise.id, :group_id => group1.id, :extension => 'pdf', :filename => 'example.pdf')
    FileUtils.cp(example_submission_file, "#{submission_path}/#{submission1.id}.pdf")

    group2 = Group.create(:exercise_id => exercise.id, :name => 'Group 2')
    group2.users << User.find_by_studentnumber('234567')
    submission2 = Submission.create(:exercise_id => exercise.id, :group_id => group2.id, :extension => 'pdf', :filename => 'example.pdf')
    FileUtils.ln_s(example_submission_file, "#{submission_path}/#{submission2.id}.pdf")

    # Assign submission
    #exercise.assign([submission1], [teacher])

    # Create example rubric
    #exercise.load_xml(File.new(SUBMISSIONS_PATH + '/esimerkki.xml'))

    return exercise
  end
end
