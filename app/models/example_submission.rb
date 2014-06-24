class ExampleSubmission < Submission
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
