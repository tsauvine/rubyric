# require "ftools"

# http://wiki.rubyonrails.org/rails/pages/HowtoUploadFiles

class Submission < ActiveRecord::Base
  belongs_to :exercise
  belongs_to :group
  has_many :reviews, {:order => :id, :dependent => :destroy }

  after_create :write_file
  #after_destroy :delete_file

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
    self.filename = Iconv.conv('UTF-8//IGNORE', 'UTF-8', @file_data.original_filename)
  end

  # Saves the file to the filesystem. This is called automatically after create
  def write_file
    # This must be called after create, because we need to know the id.

    path = "#{SUBMISSIONS_PATH}/#{exercise.id}"
    filename = "#{id}.#{extension}"
#     File.makedirs(path)

    if @file_data.is_a?(Tempfile)
      FileUtils.cp(@file_data.path, "#{path}/#{filename}")
    elsif @file_data.is_a?(StringIO)
      File.open("#{path}/#{filename}", "wb") do |file|
        file.write(@file_data.read)
      end
    end

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

    review = Review.create({:user => user, :submission => self})

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
    Review.delete_all(["submission_id=? AND user_id!=? AND status IS NULL", id, user.id])

    # Assign to user if he's not already in the list
    assign_to(user) if reviews.empty?
  end

  def late?(ex = nil)
    ex ||= self.exercise
    ex.deadline && self.created_at > ex.deadline
  end

end
