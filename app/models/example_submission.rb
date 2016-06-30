class ExampleSubmission < Submission
  
  def write_file
    logger.debug "ExampleSubmission::write_file"
    
    submission_path = "#{SUBMISSIONS_PATH}/#{exercise_id}"
    example_submission_file = "#{SUBMISSIONS_PATH}/example.pdf"
    return unless File.exists?(example_submission_file)
    
    FileUtils.makedirs(submission_path)
    FileUtils.ln(example_submission_file, "#{submission_path}/#{self.id}.pdf")
    Submission.delay.post_process(self.id)
  end
  
  def extension
    'pdf'
  end
  
  def filename
    'example.pdf'
  end
  
  def full_filename
    "#{SUBMISSIONS_PATH}/example.pdf"
  end
  
  def page_height
    27.940176
  end
  
  def page_width
    21.590136
  end

  def page_count
    1
  end
end
