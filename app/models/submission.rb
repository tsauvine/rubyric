#require "ftools"
require 'open3.rb'

# http://wiki.rubyonrails.org/rails/pages/HowtoUploadFiles

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
    
    if self.exercise.review_mode == 'annotation' && self.extension == 'pdf'
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
  def png_path(page_number, zoom)
    page_number ||= 0
    page_number = page_number.to_i
    
    zoom ||= 1.0
    zoom = zoom.to_f
    zoom = 0.01 if zoom < 0.01
    zoom = 10.0 if zoom > 10.0
    
    book_mode = true
    # TODO: use pdfinfo
    width = 1190.5 * zoom * 1.5 # 595
    height = 841.7 * zoom * 1.5
    half_width = width / 2
    
    if book_mode
      mod = page_number % 4
      div = page_number / 4
      
      if page_number % 2 == 0
        crop = " -crop #{half_width.to_i}x#{height.to_i}+#{half_width.to_i}+0"  # right side
      else
        crop = " -crop #{half_width.to_i}x#{height.to_i}+0+0"                   # left side
      end
      
      if mod == 0 || mod == 3
        pdf_page_number = div
      else
        pdf_page_number = div + 1
      end
    else
      pdf_page_number = page_number
      crop = ''
    end
    
    submission_path = self.full_filename()
    
    # Create renderings path
    FileUtils.makedirs PDF_CACHE_PATH unless File.exists? PDF_CACHE_PATH
    
    png_path = "#{PDF_CACHE_PATH}/#{id}-#{page_number}-#{(zoom * 100).to_i}.png"
    png_exists = File.exist? png_path
    
    if png_exists
      return png_path
    else
      # Convert pdf to png
      density = 72 * zoom * 1.5
      command = "convert -antialias -density #{density} #{submission_path}[#{pdf_page_number}]#{crop} #{png_path}"
      puts command
      #puts command
      system(command)  # This blocks until the png is rendered
      
      # TODO: remove obsolete renderings from cache
      # rm id-page_number*
    end
    
    return png_path
    
    # 0 => 0 right  %0 /0
    # 1 => 1 left   %1 /0
    # 2 => 1 right  %2 /0
    # 3 => 0 left   %3 /0
    # 4 => 
    # 5 => 
    # 5 => 
    # 6 => 
  end

  def page_count
    # http://pdf-toolkit.rubyforge.org/
    # https://github.com/yob/pdf-reader
    
    book_mode = true
    count = 1
    submission_path = self.full_filename()
    Open3.popen3('pdfinfo', submission_path) do |stdin, stdout, stderr, wait_thr|
      while line = stdout.gets
        next unless line =~ /^Pages/ 
        parts = line.split(':')
        next if parts.size < 2
        
        count = parts[1].strip.to_i
        break
      end
      
      exit_status = wait_thr.value
    end
    
    count *= 2 if book_mode
    
    # TODO: save page count in the DB
    
    return count
  end

end
