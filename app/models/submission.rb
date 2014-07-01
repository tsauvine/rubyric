#require "ftools"
require 'open3.rb'

# http://wiki.rubyonrails.org/rails/pages/HowtoUploadFiles

# page_width: in centimeters
# page_height: in centimeters
class Submission < ActiveRecord::Base
  belongs_to :exercise
  belongs_to :group
  has_many :reviews, {:order => :id, :dependent => :destroy }

  after_create :write_file
  #after_destroy :delete_file


  def has_member?(user)
    group.has_member?(user)
  end

  def has_reviewer?(user)
    Review.exists?(:submission_id => self.id, :user_id => user.id)
  end

  # Setter for the form's file field.
  def file=(file_data)
    @file_data = file_data

    # Get the extension
    tar = @file_data.original_filename.index('.tar.')
    if (tar)
      self.extension = @file_data.original_filename.slice(tar + 1, @file_data.original_filename.length - tar - 1)
    else
      self.extension = @file_data.original_filename.split(".").last
    end

    # Save the original filename (ignore invalid byte sequences)
    #self.filename = Iconv.conv('UTF-8//IGNORE', 'UTF-8', @file_data.original_filename) # not Rails 3 compatible
    # TODO: check if utf-8 will cause problems
    self.filename = @file_data.original_filename
  end

  # Saves the file to the filesystem. This is called automatically after create
  def write_file
    # This must be called after create, because we need to know the id.

    path = "#{SUBMISSIONS_PATH}/#{exercise.id}"
    filename = "#{id}.#{extension}"
    FileUtils.makedirs(path)

    if @file_data
      File.open("#{path}/#{filename}", "wb") do |file|
        file.write(@file_data.read)
      end
    end
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
    "#{SUBMISSIONS_PATH}/#{exercise.id}/#{id}.#{extension}"
  end

  # Assigns this submission to be reviewed by user.
  def assign_to(user)
    user = User.find(user) unless user.is_a?(User)
    options = {:user => user, :submission => self}
    
    if ['annotation', 'exam'].include?(self.exercise.review_mode) && self.extension == 'pdf'
      review = AnnotationAssessment.new(options)
    else
      review = Review.new(options)
    end
    
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
    Review.destroy_all(["submission_id=? AND user_id!=?", id, user.id])

    # Assign to user if he's not already in the list
    assign_to(user) if reviews.empty?
  end

  def late?(ex = nil)
    ex ||= self.exercise
    ex.deadline && self.created_at > ex.deadline
  end
  
  # Returns the path of the png rendeing of the submission
  # This method blocks until the png is rendered and available.
  # returns false if the png cannot be rendered
  def image_path(page_number, zoom)
    # Sanitize parameters
    page_number ||= 0
    page_number = page_number.to_i
    
    zoom ||= 1.0
    zoom = zoom.to_f
    zoom = 0.01 if zoom < 0.01
    zoom = 4.0 if zoom > 4.0
    
    # Call page count to make sure values are cached FIXME
    self.page_count()
    
    submission_path = self.full_filename()
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
      half_width = self.page_width * pixels_per_centimeter / 2
      height = self.page_height * pixels_per_centimeter
      mod = page_number % 4
      div = page_number / 4
      
      if page_number % 2 == 0
        crop = " -crop #{half_width.to_i}x#{height.to_i}+#{half_width.to_i}+0"  # right side
      else
        crop = " -crop #{half_width.to_i}x#{height.to_i}+0+0"                   # left side
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
      # TODO: book mode
      
      puts command
      system(command)  # This blocks until the png is rendered
      
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
  
  def page_count
    # http://pdf-toolkit.rubyforge.org/
    # https://github.com/yob/pdf-reader
    
    value = read_attribute(:page_count)
    return value if value != nil
    
    count = 1
    Open3.popen3('pdfinfo', self.full_filename()) do |stdin, stdout, stderr, wait_thr|
      while line = stdout.gets
        if line =~ /^Pages/  # Read page count
          parts = line.split(':')
          next if parts.size < 2
          count = parts[1].strip.to_i
        elsif line =~ /^Page size/  # Read page size
          parts = line.split(':')
          next if parts.size < 2
          
          values = parts[1].scan(/[0-9\.]+/)
          self.page_width = Float(values[0]) * 0.035278 rescue nil  # Convert points to centimeters
          self.page_height = Float(values[1]) * 0.035278 rescue nil
        end
      end
      
      exit_status = wait_thr.value
    end
    
    count *= 2 if self.book_mode
    self.page_count = count
    self.save()
    
    return count
  end

end
