#require "ftools"
require 'open3.rb'
require 'rest_client'

# http://wiki.rubyonrails.org/rails/pages/HowtoUploadFiles

# page_width: in centimeters
# page_height: in centimeters
class Submission < ActiveRecord::Base
  belongs_to :exercise
  belongs_to :group
  has_many :reviews, dependent: :destroy

  has_many :review_summaries, class_name: 'Review' #, :foreign_key => 'review_id'
  #has_many :review_summaries, :class_name => "Review", -> { select([:id, :submission_id, :status, :grade, :user_id]) }
  #, -> { where('posts.title is not null') }

  after_create :write_file

  def has_member?(user)
    group.has_member?(user)
  end

  def has_reviewer?(user)
    return false unless user
    GroupReviewer.exists?(group_id: self.group_id, user_id: user.id) ||
        Review.exists?(submission_id: self.id, user_id: user.id)
  end

  def annotatable?
    self.annotatable
  end

  def pdf_filename
    if self.conversion
      self.converted_pdf_filename()
    else
      self.full_filename()
    end
  end

  # Setter for the form's file field.
  def file=(file_data)
    @file_data = file_data

    if file_data.is_a?(Mail::Part)
      filename = @file_data.filename
    else
      filename = @file_data.original_filename
    end

    # Get the extension
    tar = filename.index('.tar.')
    if tar
      self.extension = filename.slice(tar + 1, filename.length - tar - 1)
    else
      self.extension = filename.split('.').last
    end

    # Save the original filename (ignore invalid byte sequences)
    #self.filename = Iconv.conv('UTF-8//IGNORE', 'UTF-8', filename) # not Rails 3 compatible
    # TODO: check if utf-8 will cause problems
    self.filename = filename
  end

  # Saves the file to the filesystem. This is called automatically after create.
  # (This must be called after create, because we need to know the id.)
  def write_file
    return unless @file_data || self.payload

    path = "#{SUBMISSIONS_PATH}/#{exercise.id}"
    filename = "#{id}.#{extension}"
    FileUtils.makedirs(path)

    File.open("#{path}/#{filename}", 'wb') do |file|
      if @file_data
        file.write(@file_data.read)
      else
        file.write(self.payload)
      end
    end

    Submission.delay.post_process(self.id) # (run_at: 5.seconds.from_now)
  end

  def move(target_exercise)
    # Move file
    target_path = "#{SUBMISSIONS_PATH}/#{target_exercise.id}"
    FileUtils.makedirs(target_path)
    FileUtils.mv(full_filename, "#{target_path}/")

    # Move submission
    self.exercise_id = target_exercise.id
    save()
  end

  #def delete_file
  #  FileUtils.rm_rf("#{SUBMISSIONS_PATH}/#{id}")
  #end

  # Returns the location of the submitted file in the filesystem.
  def full_filename
    "#{SUBMISSIONS_PATH}/#{exercise_id}/#{id}.#{extension}"
  end

  def converted_html_filename
    "#{SUBMISSIONS_PATH}/#{exercise_id}/#{id}-converted.html"
  end

  def converted_pdf_filename
    "#{SUBMISSIONS_PATH}/#{exercise_id}/#{id}-converted.pdf"
  end

  def thumbnail_path
    "#{SUBMISSIONS_PATH}/#{exercise_id}/#{id}-thumbnail.jpg"
  end

  def has_html_view?
    conversion == 'html'
  end

  def html_view
    return IO.read(converted_html_filename)
  end

  # Returns the first thing in payload that looks like a URL (begins with http://).
  def payload_url
    return if payload.blank?

    match = /https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&\/=]*)/.match(payload)
    return match[0] if match
  end

  def video?
    url = payload_url
    return false unless url
    url = url.strip.downcase

    return true if url =~ /^http(s)?:\/\/.*panopto/
    return true if url =~ /^http(s)?:\/\/www\.youtube\.com\/watch/
    return true if url =~ /^http(s)?:\/\/youtu\.be\//

    return false
  end


  # Assigns this submission to be reviewed by user.
  def assign_to(user, lti_launch_params=nil)
    user = User.find(user) unless user.is_a?(User)
    options = {user: user, submission: self}

    if %w(annotation exam).include?(self.exercise.review_mode) && self.annotatable?
      review = AnnotationAssessment.new(options)
    else
      review = Review.new(options)
    end

    review.lti_launch_params = lti_launch_params

    review.save

    return review
  end

  def assign_once_to(user)
    user = User.find(user) unless user.is_a?(User)

    return false if Review.exists?(:user_id => user.id, :submission_id => self.id)

    assign_to(user)
  end

  # Assigns this submission to be reviewed by user, and removes previous assignments.
  def assign_to_exclusive(user)
    # Load user
    user = User.find(user) unless user.is_a?(User)

    # Remove other reviewers
    Review.destroy_all(['submission_id=? AND user_id!=?', id, user.id])

    # Assign to user if he's not already in the list
    assign_to(user) if reviews.empty?
  end

  def late?(exercise)
    exercise.deadline && self.created_at > exercise.deadline
  end

  # Returns the path of a bitmap rendering of the submission
  # This method blocks until the bitmap is rendered and available.
  # raises ActiveRecord::RecordNotFound if image is not renderable
  def image_path(page_number, zoom)
    # Sanitize parameters
    zoom ||= 1.0
    zoom = zoom.to_f
    zoom = 0.01 if zoom < 0.01
    zoom = 4.0 if zoom > 4.0

    page_number ||= 0
    page_number = page_number.to_i
    if self.extension == 'pdf' || self.conversion == 'pdf'
      return image_path_pdf(page_number, zoom)
    elsif self.conversion == 'image'
      return image_path_bitmap(zoom)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def image_path_pdf(page_number, zoom)
    # Call page count to make sure values are cached FIXME
    self.page_count()

    submission_path = self.pdf_filename()
    image_format = 'png'
    image_mimetype = 'image/png'
    #image_format = 'jpg'
    #image_mimetype = 'image/jpeg'
    image_quality = '50'
    image_filename = "#{id}-#{page_number}-#{(zoom * 100).to_i}.#{image_format}"
    image_path = "#{PDF_CACHE_PATH}/#{image_filename}"
    image_exists = File.exist? image_path
    pixels_per_centimeter = 45.0 * zoom

    if self.book_mode
      #half_width = self.page_width * pixels_per_centimeter / 2
      #height = self.page_height * pixels_per_centimeter
      mod = page_number % 4
      div = page_number / 4

      if page_number % 2 == 0
        #crop = " -crop #{half_width.to_i}x#{height.to_i}+#{half_width.to_i}+0"  # right side
        gravity = 'East'
      else
        #crop = " -crop #{half_width.to_i}x#{height.to_i}+0+0"                   # left side
        gravity = 'West'
      end

      if mod == 0 || mod == 3
        pdf_page_number = div * 2
      else
        pdf_page_number = div * 2 + 1
      end
    else
      pdf_page_number = page_number
      crop = ''
    end

    # Create renderings path
    FileUtils.makedirs PDF_CACHE_PATH unless File.exists? PDF_CACHE_PATH

    unless image_exists
      # Convert pdf to bitmap
      #command = "convert -antialias -density #{4 * pixels_per_centimeter * 2.54} -resize 25% -quality #{image_quality} #{submission_path}[#{pdf_page_number}]#{crop} #{image_path}"

      command = "gs -q -dNumRenderingThreads=4 -dNOPAUSE -sDEVICE=pngalpha -dFirstPage=#{pdf_page_number+1} -dLastPage=#{pdf_page_number+1} -sOutputFile=#{image_path} -r#{pixels_per_centimeter * 2.54} #{submission_path} -c quit"
      # -sDEVICE=jpeg -dJPEGQ=90
      #puts command
      system(command) # This blocks until the png is rendered

      if self.book_mode
        command = "convert -gravity #{gravity} -crop 50%x100% #{image_path} #{image_path}"
        system(command)
      end

      # TODO: remove obsolete renderings from cache
      # rm id-page_number*
    end

    return {path: image_path, filename: image_filename, mimetype: image_mimetype}

    # 0 => 0 right
    # 1 => 1 left
    # 2 => 1 right
    # 3 => 0 left
    # 4 => 2 right
    # 5 => 3 left
    # 6 => 3 right
    # 7 => 2 left
  end

  def image_path_bitmap(zoom)
    image_mimetype = Mime::Type.lookup_by_extension(self.extension.downcase)
    image_filename = "#{id}-#{(zoom * 100).to_i}.#{self.extension}"
    image_path = "#{PDF_CACHE_PATH}/#{image_filename}"
    logger.debug "converted image path: #{image_path}"
    logger.debug "mime type: #{image_mimetype}"

    # Don't convert if zoom == 1
    if zoom == 1.0
      logger.debug 'zoom=1, skip conversion'
      return {path: self.full_filename(), filename: image_filename, mimetype: image_mimetype}
    end

    # Create renderings path
    FileUtils.makedirs PDF_CACHE_PATH unless File.exists? PDF_CACHE_PATH

    unless File.exist? image_path
      # Convert pdf to bitmap
      command = "convert -antialias -resize #{zoom * 100}% #{self.full_filename()} #{image_path}"
      logger.debug command
      system(command) # This blocks until the bitmap is rendered

      # TODO: remove obsolete renderings from cache
      # rm id-*
    end

    return {path: image_path, filename: image_filename, mimetype: image_mimetype}
  end


  # Post-processes the submission. ASCII files are converted to HTML with a syntax highlighter.
  # TODO: Doc and Docx files are converted to PDF with LibreOffice.
  def self.post_process(id)
    submission = Submission.find(id)

    non_annotatable_extensions = ['rkt']

    # Try to recognize submission type
    unless submission.filename.blank?
      Open3.popen3('file', submission.full_filename()) do |stdin, stdout, stderr, wait_thr|
        line = stdout.gets
        parts = line.strip.split(':')
        logger.debug "File type: (#{parts[1]})"

        if parts.size < 1
          logger.error "file command failed: #{line}"
          return
        elsif parts[1].include?('text') && !non_annotatable_extensions.include?(submission.extension)
          logger.info 'Converting plain text to html'
          submission.convert_ascii_to_html(parts[1])
        elsif parts[1].include?('PDF document')
          logger.info 'Post processing pdf'
          submission.postprocess_pdf()
        elsif parts[1].include?('Composite Document File') || parts[1].include?('Microsoft Word')
          logger.info 'Converting DOC to PDF'
          submission.convert_doc_to_pdf()
        elsif parts[1].include?('image data')
          logger.info 'Post processing image'
          submission.postprocess_image()
        else
          return
        end
      end
#     else
#       submission.convert_plaintext_payload_to_pdf()
    end

    if submission.exercise.collaborative_mode == 'review' && %w(annotation exam).include?(submission.exercise.review_mode) && submission.annotatable? && !AnnotationAssessment.exists?(:submission_id => submission.id, :user_id => nil)
      AnnotationAssessment.create(:submission_id => submission.id)
    end

    # FIXME: this is a temporary hack for Koodiaapinen
    if submission.is_a?(AplusSubmission) && submission.exercise.rubric_grading_mode == 'always_pass'
      FeedbackMailer.aplus_feedback(submission.id)
    end
  end

  def postprocess_pdf
    logger.info 'Post processing pdf'
    self.annotatable = true

    # TODO: get page count and page sizes
    self.page_count = 1
    page_sizes = []
    Open3.popen3("pdfinfo -l -1 #{self.pdf_filename()}") do |stdin, stdout, stderr, wait_thr|
      while line = stdout.gets
        # Do encoding to handle invalid utf-8 characters that sometimes appear in the output of pdfinfo
        line = line.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')

        if line =~ /^Pages/ # Read page page_count
          parts = line.split(':')
          next if parts.size < 2

          self.page_count = parts[1].strip.to_i
          self.page_count *= 2 if self.book_mode
        elsif line =~ /^Page.*size/ # Read page size
          logger.info "Page size: (#{line.strip})"
          parts = line.split(':')
          next if parts.size < 2

          values = parts[1].scan(/[0-9\.]+/)
          page_width = Float(values[0]) * 0.035278 rescue nil # Convert points to centimeters
          page_height = Float(values[1]) * 0.035278 rescue nil
          logger.info "Page size: #{page_width}x#{page_height}"
          page_width /= 2 if self.book_mode && page_width

          self.page_height = page_height unless self.page_height
          self.page_width = page_width unless self.page_width
          page_sizes << [page_width, page_height]
        end
      end

      exit_status = wait_thr.value
    end
    logger.info "Page sizes: #{page_sizes}"

    self.page_sizes = JSON.generate(page_sizes)
    logger.info "Page sizes, JSON: #{self.page_sizes}"

    # Generate thumbnail
    pixels_per_centimeter = THUMBNAIL_DEFAULT_SIZE.to_f / self.page_height
    command = "gs -q -dNumRenderingThreads=4 -dNOPAUSE -sDEVICE=jpeg -dJPEGQ=80 -dFirstPage=1 -dLastPage=1 -sOutputFile=#{self.thumbnail_path()} -r#{pixels_per_centimeter * 2.54} #{self.pdf_filename()} -c quit"
    system(command)
    logger.debug command

    self.save()
  end

  def postprocess_image
    self.page_count = 1
    self.annotatable = true
    self.conversion = 'image'

    # Get size
    Open3.popen3("identify -format \"%wx%h\" #{self.full_filename()}") do |stdin, stdout, stderr, wait_thr|
      line = stdout.gets
      parts = line.split('x')

      if parts.size < 1
        logger.error "failed to determine image size: #{line}"
        return
      else
        self.page_width = parts[0].to_i / 45.0
        self.page_height = parts[1].to_i / 45.0
      end
    end

    size = [self.page_width, self.page_height].max.to_f
    zoom = THUMBNAIL_DEFAULT_SIZE / (size * 45.0)

    # Generate thumbnail
    command = "convert -antialias -resize #{zoom * 100}% #{self.full_filename()} #{self.thumbnail_path()}"
    system(command)

    self.save()
  end

  def convert_ascii_to_html(file_type)
    parts = file_type.split(',')

    enable_syntax_highlight = !parts[0].include?('text')

    # Syntax hilighting
    if enable_syntax_highlight
      command = "pygmentize -O linespans=line -f html -o #{converted_html_filename} #{self.full_filename}"
      if !system(command)
        # Pygmentize failed. Try again with plaintext lexer.
        enable_syntax_highlight = false
        #         command = "pygmentize -f html -l text -o #{converted_html_filename} #{self.full_filename}"
        #         if !system(command)
        #           logger.warn "pygmentize is unable to convert #{self.full_filename} to HTML"
        #           return false
        #         end
      end
    end

    unless enable_syntax_highlight
      File.open(converted_html_filename, "w") do |file|
        width = 80
        content = IO.read(self.full_filename).gsub('<', '&lt;').gsub('>', '&gt;')
        content = content.scan(/\S.{0,#{width}}\S(?=\s|$)|\S+/)
        content = '<div class="highlight"><pre>' + content.join("\n") + '</pre></div>'

        file.write(content)
      end
    end

    # Convert to PDF
    #     command = "wkhtmltopdf.sh -d 50 -B 0mm -L 0mm -R 0mm -T 0mm #{converted_html_filename} #{converted_pdf_filename}"
    #     logger.info command
    #     if !system(command)
    #       logger.warn "wkhtmltopdf is unable to convert #{converted_html_filename} to PDF"
    #       return
    #     end

    self.conversion = 'html'
    self.annotatable = true
    self.save()
    #self.postprocess_pdf()
  end

  def convert_doc_to_pdf()
    # TODO
    # self.annotatable = true
    # self.conversion = 'pdf'
  end


  def page_count
    # http://pdf-toolkit.rubyforge.org/
    # https://github.com/yob/pdf-reader

    value = read_attribute(:page_count)
    return value if value != nil

    count = 1
    default_page_size = nil
    page_sizes = {}
    Open3.popen3('pdfinfo', "-l -1 #{self.full_filename()}") do |stdin, stdout, stderr, wait_thr|
      # Do encoding to handle invalid utf-8 characters that sometimes appear in the output of pdfinfo
      while line = stdout.gets
        line = line.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
        if line =~ /^Pages/ # Read page count
          parts = line.split(':')
          next if parts.size < 2
          count = parts[1].strip.to_i
        elsif line =~ /^Page size/ # Read page size
          parts = line.split(':')
          next if parts.size < 2

          values = parts[1].scan(/[0-9\.]+/)
          self.page_width = Float(values[0]) * 0.035278 rescue nil # Convert points to centimeters
          self.page_height = Float(values[1]) * 0.035278 rescue nil
        end
      end

      exit_status = wait_thr.value
    end

    if self.book_mode
      count *= 2
      self.page_width /= 2
    end

    self.page_count = count
    self.save()

    return count
  end
end
