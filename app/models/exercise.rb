require 'shellwords.rb'
require 'rexml/document'
include REXML

class Exercise < ActiveRecord::Base
  belongs_to :course_instance
  has_many :groups
  has_many :submissions

  validates :groupsizemin, numericality: {only_integer: true, greater_than: 0}
  validates :groupsizemax, numericality: {only_integer: true, greater_than_or_equal_to: :groupsizemin}
  validates :lti_resource_link_id, uniqueness: {scope: :course_instance_id, message: 'resource link ID already taken', allow_blank: true}
  validates_presence_of :name
  validate :use_allowed_extensions_only

  ALLOWED_EXTS = %w(doc docx pdf png jpg jpeg)

  # Feedback grouping options: exercise, sections, categories


  def rubric_grading_mode
    return nil if self.rubric.blank?
    rubric_content()['gradingMode']
  end

  def max_grade
    return nil if self.rubric.blank?
    rubric = rubric_content()

    case rubric['gradingMode']
      when 'average'
        max_grade = nil
        rubric['grades'].each do |grade|
          begin
            num_grade = Float(grade)
            max_grade = num_grade if !max_grade || num_grade > max_grade
          rescue ArgumentError => e
          end
        end
        return max_grade
      when 'sum'
        sum = 0.0
        rubric['pages'].each do |page|
          begin
            sum += Float(page['maxSum'] || 0)
          rescue ArgumentError => e
          end
        end
        return sum
      else
        return nil
    end
  end

  def peer_review?
    peer_review_goal && peer_review_goal != 0
  end

  def peer_review_active?
    peer_review_goal && peer_review_goal != 0 && (peer_review_timing != 'after_deadline' || Time.now > deadline)
  end

  # Returns a relation representing groups who have submitted this exercise. Users and submissions are eager loaded.
  def groups_with_submissions
    Group.where(course_instance_id: self.course_instance_id)
        .includes([:reviewers, {group_members: :user}, {submissions: {reviews: :user}}])
        .where(submissions: {exercise_id: self.id})
  end

  # Assigns submissions evenly to the given users
  # submission_ids: array of submission ids
  # users: array of user objects
  # exclusive: previous assignments are erased
  def assign(submission_ids, user_ids)
    #submissions = Submission.find(submission_ids)

    counter = 0
    n = user_ids.size

    return if n < 1

    submission_ids.each do |submission_id|
      assistant_id = user_ids[counter % n]

      Review.create(:user_id => assistant_id, :submission_id => submission_id)
      #if exclusive
      #  submission.assign_to_exclusive(assistant)
      #else
      #submission.assign_to(assistant)
      #end

      counter += 1
    end
  end

  def rubric_content
    return @rubric_content if defined?(@rubric_content)
    @rubric_content = JSON.parse(self.rubric || {})
  end

  # Populates the rubric with some example data.
  # This erases the existing rubric.
  def initialize_example
    # TODO
  end

  # rubric: string
  def load_rubric(rubric)
    looks_like_xml = rubric[0] == '<'

    if looks_like_xml
      load_xml1(rubric)
    else
      self.rubric = rubric
    end
  end

  # Load rubric from an XML file (version Rubyric 1).
  # This erases the existing rubric.
  def load_xml1(file)
    # Parse XML
    doc = REXML::Document.new(file)

    page_counter = 0
    criterion_counter = 0
    phrase_counter = 0
    pages = []
    rubric = {version: '2', pages: pages}

    # Categories
    positive_caption_element = REXML::XPath.first(doc, '/rubric/positive-caption')
    positive_caption = 'Strengths'
    positive_caption = positive_caption_element.text.strip if positive_caption_element and positive_caption_element.text

    negative_caption_element = REXML::XPath.first(doc, '/rubric/negative-caption')
    negative_caption = 'Weknesses'
    negative_caption = negative_caption_element.text.strip if negative_caption_element and negative_caption_element.text

    neutral_caption_element = REXML::XPath.first(doc, '/rubric/neutral-caption')
    neutral_caption = 'Other comments'
    neutral_caption = neutral_caption_element.text.strip if neutral_caption_element and neutral_caption_element.text

    rubric['feedbackCategories'] = [{id: 0, name: positive_caption}, {id: 1, name: negative_caption}, {id: 2, name: neutral_caption}]

    # Final comment
    final_comment_element = REXML::XPath.first(doc, '/rubric/final-comment')
    finalcomment = ''
    finalcomment = final_comment_element.text.strip if final_comment_element and final_comment_element.text

    rubric['finalComment'] = finalcomment

    rubric['gradingMode'] = 'average'

    # Categories
    doc.each_element('rubric/category') do |category|
      # Sections
      category.each_element('section') do |section|
        criteria = []

        new_page = {id: page_counter, name: section.attributes['name'], criteria: criteria}
        new_page['weight'] = section.attributes['weight'] if section.attributes['weight']
        pages << new_page
        page_counter += 1

        #Items
        section.each_element('item') do |item|
          phrases = []
          new_criterion = {id: criterion_counter, name: item.attributes['name'], phrases: phrases}
          criteria << new_criterion
          criterion_counter += 1

          # Phrases
          item.each_element('phrase') do |phrase|
            case phrase.attributes['type']
              when 'Neutral'
                categoryId = 2
              when 'Bad'
                categoryId = 1
              else # Good
                categoryId = 0
            end

            phrase.text ||= ''
            phrases << {id: phrase_counter, text: phrase.text.strip, category: categoryId}
            phrase_counter += 1
          end

          # Item grading options
          #item.each_element('grade') do |grading_option|
          #  igo_counter += 1
          #  new_grading_option = ItemGradingOption.new({:text => grading_option.text.strip, :position => igo_counter})
          #  new_item.item_grading_options << new_grading_option
          #end
        end # items

        # Section grading options
        rubric['grades'] = grades = []
        section.each_element('grade') do |grading_option|
          raw_grade = grading_option.text.strip
          grade = Float(raw_grade) rescue raw_grade # Convert to number if possible
          grades << grade
        end

      end # sections
    end # categories

    self.rubric = rubric.to_json
  end


  def generate_xml
    doc = Document.new
    root = doc.add_element 'rubric'

    # Categories
    categories.each do |category|
      category_element = root.add_element 'category', {'name' => category.name, 'weight' => category.weight}

      # Section
      category.sections.each do |section|
        section_element = category_element.add_element 'section', {'name' => section.name, 'weight' => section.weight}

        # Items
        section.items.each do |item|
          item_element = section_element.add_element 'item', {'name' => item.name}

          # Phrases
          item.phrases.each do |phrase|
            phrase_element = item_element.add_element 'phrase', {'type' => phrase.feedbacktype}
            phrase_element.add_text phrase.content
          end

          # Item grades
          item.item_grading_options.each do |grading_option|
            item_go_element = item_element.add_element 'grade'
            item_go_element.add_text grading_option.text
          end

        end

        # Section grades
        section.section_grading_options.each do |grading_option|
          section_go_element = section_element.add_element 'grade', {'points' => grading_option.points}
          section_go_element.add_text grading_option.text
        end

      end
    end

    # Properties
    final_comment = root.add_element 'final-comment'
    final_comment.add_text self.finalcomment

    positive_caption = root.add_element 'positive-caption'
    positive_caption.add_text self.positive_caption

    negative_caption = root.add_element 'negative-caption'
    negative_caption.add_text self.negative_caption

    neutral_caption = root.add_element 'neutral-caption'
    neutral_caption.add_text self.neutral_caption

    feedback_grouping = root.add_element 'feedback-grouping'
    feedback_grouping.add_text self.feedbackgrouping

    # Write the XML, intendation = 2 spaces
    output = ""
    doc.write(output, 2)

    return output
  end

  # Returs a grade distribution histogram [[grade,count],[grade,count],...]
  def grade_distribution(grader = nil)
    if grader
      reviews = Review.all(joins: 'FULL JOIN submissions ON reviews.submission_id = submissions.id ', conditions: ['exercise_id = ? AND user_id = ? AND calculated_grade IS NOT NULL', self.id, grader.id])
    else
      reviews = Review.all(joins: 'FULL JOIN submissions ON reviews.submission_id = submissions.id ', conditions: ['exercise_id = ?  AND calculated_grade IS NOT NULL', self.id])
    end

    # group reviews by grade  [ [grade,[review,review,...]], [grade,[review,review,...]], ...]
    reviews_by_grade = reviews.group_by { |review| review.calculated_grade }

    # count reviews in each bin [ [grade, count], [grade,count], ... ]
    histogram = reviews_by_grade.collect { |grade, stats| [grade, stats.size] }

    # sort by grade
    histogram.sort { |x, y| x[0] <=> y[0] }
  end

  def annotation_points
    rubric = JSON.parse(self.rubric)

    criteria_by_id = {}
    criterion_id_by_phrase_id = {}
    page_id_by_phrase_id = {}
    rubric['pages'].each do |page|
      page['criteria'].each do |criterion|
        criterion['phrases'].each do |phrase|
          criteria_by_id[criterion['id']] = criterion
          criterion_id_by_phrase_id[phrase['id']] = criterion['id']
          page_id_by_phrase_id[phrase['id']] = page['id']
        end
      end
    end

    # review=Review.find(44622)
    # annotations = JSON.parse(review.payload)
    # exercise = Exercise.find(1008)
    # rubric = JSON.parse(exercise.rubric)
    File.open('results.csv', 'w') do |output|
      Group.where(:course_instance_id => self.course_instance_id).find_each do |group|
        puts group
        group.submissions.each do |submission|
          puts submission
          submission.reviews.each do |review|
            #review = Review.find(44405)

            annotations = JSON.parse(review.payload)['annotations']
            students = review.submission.group.users

            criterion_points = {} # criterion_id => float
            page_points = {} # page_id => float
            annotations.each do |annotation|
              #puts annotation
              criterion_id = criterion_id_by_phrase_id[annotation['phrase_id']]
              page_id = page_id_by_phrase_id[annotation['phrase_id']]

              grade = Float(annotation['grade']) rescue 0

              #puts "#{page_id}/#{criterion_id}: #{grade}"

              criterion_points[criterion_id] ||= 0
              criterion_points[criterion_id] += grade
              page_points[page_id] ||= 0
              page_points[page_id] += grade
            end

            output.print students[0].studentnumber
            rubric['pages'].each do |page|
              #page['criteria'].each do |criterion|
              #  print criterion_points[criterion['id']]
              #end
              output.print ', '

              unless page_points[page['id']].nil?
                output.print page_points[page['id']].ceil
              end
            end
            output.puts
          end
        end
      end
    end


  end

  # Assign submissions to assistants
  # csv: student, assistant
  def batch_assign(csv)
    counter = 0

    # Make an array of lines
    array = csv.split(/\r?\n|\r(?!\n)/)

    Exercise.transaction do
      array.each do |line|
        parts = line.split(',', 2).map { |s| s.strip }
        next if parts.size < 1

        submission_studentnumber = parts[0]
        assistant_studentnumber = parts[1]

        # Find submissions that belong to the student
        submissions = Submission.all(conditions: ['groups.exercise_id = ? AND users.studentnumber = ?', self.id, submission_studentnumber], joins: {group: :users})
        grader = User.find_by_studentnumber(assistant_studentnumber)

        next unless grader

        # Assign those submissions
        submissions.each do |submission|
          counter += 1 if submission.assign_once_to(grader)
        end
      end

      return counter
    end
  end

  def archive(options = {})
    only_latest = options.include? :only_latest
    group_subdirs = true

    t = Time.now.strftime("%Y%m%d%H%M%S")
    archive_path = TMP_PATH + "/rubyric-#{self.id}-#{t}.tar.gz"
    #logger.debug("Archive: #{archive_path}")
    #logger.debug("TempDir: #{temp_dir}")
    content_dir_name = escape_filename("rubyric-#{self.name}")
    #logger.debug("ContentDir: #{content_dir_name}")

    # Make a temp directory. It is deleted automatically after the block returns.
    #Dir.mktmpdir("rubyric") do |temp_dir|
    temp_dir = TMP_PATH + "/rubyric-#{self.id}-#{t}"
    Dir.mkdir(temp_dir)
    # Create the actual content directory so that it has a sensible name in the archive
    Dir.mkdir "#{temp_dir}/#{content_dir_name}"

    # Add contents
    groups.each do |group|
      group_dir_name = "#{temp_dir}/#{content_dir_name}/#{escape_filename(group.users.map { |user| user.studentnumber || user.email }.join('-'))}"
      Dir.mkdir group_dir_name if group_subdirs && !Dir.exists?(group_dir_name)

      group.submissions.each do |submission|

        # Link the submissionn
        source_filename = submission.full_filename

        if group_subdirs
          target_filename = "#{group_dir_name}/#{escape_filename(submission.filename)}"
        else
          target_filename = "#{temp_dir}/#{content_dir_name}/#{escape_filename(group.users.map { |user| user.studentnumber || user.email }.join('-'))}-#{submission.created_at.strftime('%Y%m%d%H%M%S')}"
          target_filename << ".#{escape_filename(submission.extension)}" unless submission.extension.blank?
        end

        FileUtils.ln_s(source_filename, target_filename) if File.exist?(source_filename)
        #logger.debug("Link #{source_filename} -> #{target_filename}")

        # Take only one file per group?
        break if only_latest
      end
    end

    # Archive the folder
    #puts "tar -zcf #{archive.path()} #{content_dir_name}"
    command = "tar -zc --dereference --directory #{temp_dir} --file #{archive_path} #{content_dir_name}"
    #logger.debug(command)
    system(command)
    #end

    return archive_path
  end

  def archive_filename
    escape_filename("rubyric-#{self.name}.tar.gz")
  end

  def escape_filename(original)
    original.gsub(/\s+/, '_').gsub(/[^\w@.-]/, '')
  end

  # Creates example submissions for existing groups.
  def create_example_submissions
    self.course_instance(true).groups.each do |group|
      submission = ExampleSubmission.create(:exercise_id => self.id, :group_id => group.id, :extension => 'pdf', :filename => 'example.pdf')
    end
  end

  def disk_space
    path = "#{SUBMISSIONS_PATH}/#{self.id}"
    `du -s #{path}`.split("\t")[0].to_i
  end


  # Schedules review mails to be sent.
  # review_ids: array of ids or a singular id
  def deliver_reviews(review_ids)
    # Send a warning to admin if delayed_job queue is long
    ErrorMailer.long_mail_queue.deliver if Delayed::Job.count > 1

    Review.where(:id => review_ids, :status => 'finished').update_all(:status => 'mailing')

    Review.delay.deliver_reviews(review_ids)
  end

  def initialize_example_rubric
    self.rubric = '{"version":"2","pages":[{"id":1,"name":"Final report","criteria":[{"id":1,"name":"Structure","phrases":[{"id":1,"text":"The report is well structured and easy to read.","grade":5},{"id":2,"text":"The report needs some structuring (e.g. introduction, methods, results, conclusions).","grade":3},{"id":5,"text":"The report is difficult to read because it\'s not logically structured.","grade":1},{"id":6,"text":"For example, the conclusions should be in a separate section and not among results."}]},
{"id":2,"name":"Scope","phrases":[{"id":3,"text":"The work is well scoped.","grade":5},{"id":4,"text":"The scope is too narrow.","grade":3},{"id":7,"text":"The scope is too wide.","grade":3},{"id":8,"text":"The project does not meet the minimum requirements.","grade":"Fail"}]},
{"id":3,"name":"Figures","phrases":[{"id":9,"text":"The figures are well made.","grade":5},{"id":10,"text":"There are some shortcomings in the figures.","grade":3},{"id":12,"text":"The scales should start from zero."},{"id":13,"text":"The figures are not referenced from text."},{"id":11,"text":"Some figures could have been used to illustrate the results.","grade":1}]}]}],"feedbackCategories":[],"grades":["Fail",1,2,3,4,5],"gradingMode":"average","finalComment":""}'
  end


  # returns a Hash: {'student_id' => [grade, grade, ...]}
  def student_results
    results = {}

    Group.where(:course_instance_id => self.course_instance_id).includes([{:submissions => [:reviews => :user, :group => :users]}, :users]).each do |group|
      group.submissions.each do |submission|
        next unless submission.exercise_id == self.id
        submission.reviews.each do |review|
          next unless review.include_in_results?

          group.group_members.each do |member|
            student_id = member.user.studentnumber || member.user.email
            results[student_id] ||= []
            results[student_id] << review.grade
          end
        end
      end
    end

    results
  end

  # returns a Hash
  # {
  #   "objects": [
  #     {
  #       "students_by_student_id": [
  #         "XXXXX1"
  #       ],
  #       "feedback": "Nicely solved exercise!",
  #       "grader": X1,
  #       "exercise_id": Z1,
  #       "submission_time": "2014-09-24 11:50",
  #       "points": 100
  #     },
  #     {
  #       "students_by_student_id": [
  #         "XXXXX2"
  #       ],
  #       "feedback": "You can do better!",
  #       "grader": X1,
  #       "exercise_id": Z2,
  #       "submission_time": "2014-09-24 11:50",
  #       "points": 20
  #     },
  #     {
  #       "students_by_email": [
  #         "none@no.email"
  #       ],
  #       "feedback": "Last one.",
  #       "grader": X1,
  #       "exercise_id": Z2,
  #       "submission_time": "2014-09-24 11:50",
  #       "points": 1
  #     }
  #   ]
  # }
  def aplus_results
    # TODO: implement
    results = {}

    Group.where(:course_instance_id => self.course_instance_id).includes([{:submissions => [:reviews => :user, :group => :users]}, :users]).each do |group|
      group.submissions.each do |submission|
        next unless submission.exercise_id == self.id
        submission.reviews.each do |review|
          next unless review.include_in_results?

          group.group_members.each do |member|
            student_id = member.user.studentnumber || member.user.email
            results[student_id] ||= []
            results[student_id] << review.grade
          end
        end
      end
    end

    results
  end


  # Returns the results for each student
  # [
  #    {:member => GroupMember, :reviewer => User, :review => Review, :submission => Submission, :grade => String/Integer, :notes => String}
  #    ...
  # ]
  # mode: all, mean, n_best
  def results(groups, options = {})
    results = []

    groups.each do |group|
      group_result = group.result(self, options)
      
      # Construct result
      if options[:include_all]
        group.group_members.each do |member|
          group_result[:reviews].each do |review|
            results << {member: member, reviewer: review.user, review: review, submission: review.submission, grade: review.grade}
          end
        end
      else
        group.group_members.each do |member|
          notes = group_result[:not_enough_reviews] ? 'Not enough reviews.' : ''
          #resultline = {member: member, grade: group_result[:grade], notes: notes}
          resultline = group_result.merge({member: member, notes: notes})

          if options[:include_peer_review_count] && member.user
            peer_review_count = member.user.peer_review_count(self)
            resultline[:created_peer_review_count] = peer_review_count[:created_peer_reviews]
            resultline[:finished_peer_review_count] = peer_review_count[:finished_peer_reviews]
          end

          results << resultline unless group_result[:no_submissions]
        end
      end
    end

    return results
  end

  # Returns the id of the review that is next in sequence for the user.
  # Returns nil if no more reviews are in queue.
  def next_review(user, done_review)
    done_group_id = done_review.submission.group_id

    groups = self.groups_with_submissions.order('groups.id, submissions.created_at DESC, reviews.id')

    # Find the next group
    previous_group_id = nil
    next_group = nil
    groups.each do |group|
      if previous_group_id == done_group_id
        next_group = group
        break
      end
      previous_group_id = group.id
    end

    return nil unless next_group

    # Find the first review of the group
    next_group.submissions.each do |submission|
      next unless submission.exercise_id == self.id
      return submission.reviews.first unless submission.reviews.empty?
    end

    # No review found. Create a new review.
    submission = next_group.submissions.first
    return nil unless submission
    submission.assign_to(user)
  end

  private

  def use_allowed_extensions_only
    extensions = allowed_extensions.split()
    unless extensions & ALLOWED_EXTS == extensions
      errors.add :allowed_extensions, 'some extensions are invalid'
    end
  end

end
