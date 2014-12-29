class BatchUploader
  
  def initialize(course_instance)
    @students_by_studentnumber = {}  # 'studentnumber' => User
    @students_by_lti_user_id = {}    # 'lti_user_id' => User
    @students_by_email = {}          # 'email' => User
    
    # Index existing students
    course_instance.students.each do |student|
      @students_by_studentnumber[student.studentnumber.strip.downcase] = student if student.studentnumber
      @students_by_lti_user_id[student.lti_user_id.strip]              = student if student.lti_user_id
      @students_by_email[student.email.strip.downcase]                 = student if student.email
    end
    
    # Load existing groups
    @groups_by_user_id = {}     # student_id => [array of groups where the student belongs]
    course_instance.groups.includes(:users, :reviewers).each do |group|
      group.users.each do |student|
        @groups_by_user_id[student.id] ||= []
        @groups_by_user_id[student.id] << group
      end
    end
  end

  
  # student_keys: array, e.g. ['student_key1', 'student_key2', ...], where a student_key can be email, studentnumber or lti_id
  # returns a group or nil
  def find_or_create_group(student_keys, course_instance, options = {})
    # parts = line.split(';')
    # student_keys = parts[0].split(',')
    
    # Find or create students
    current_groups = []     # Array of arrays of Groups, [[groups of first student], [groups of second student], ...]
    group_students = []     # Array of User objects that were loaded or created
    student_keys.each do |search_key|
      search_key = search_key.strip
      next if search_key.empty?
      
      student = @students_by_studentnumber[search_key.downcase] || @students_by_email[search_key.downcase] || @students_by_lti_user_id[search_key] || create_student(search_key, course_instance)
      
      if student
        current_groups << @groups_by_user_id[student.id] || []
        group_students << student
      end
    end
    
    return nil if group_students.empty? && !options[:allow_empty_groups]
    
    # Calculate the intersection of students' current groups, ie. find the groups that contain all of the given students.
    groups = current_groups.inject(:&) || []
    
    # The list now contains the groups with the requested students but possibly extra students as well.
    # Find the group that contains the requested amount of students.
    group = groups.select{|g| g.users.size == group_students.size}.first
    
    # Create group if not found
    unless group
      if group_students.empty?
        group_name = '<untitled group>'
      else
        group_name = (group_students.collect { |user| user.studentnumber }).join('_') # FIXME; studentnumber may be missing
      end
      
      group = Group.new(:name => group_name, :course_instance_id => course_instance.id, :max_size => group_students.size)
      group.save(:validate => false)

      group_students.each do |student|
        member = GroupMember.new(:email => student.email, :studentnumber => student.studentnumber)
        member.group = group
        member.user = student
        member.save(:validate => false)
        group.group_members << member
        
        @groups_by_user_id[student.id] ||= []
        @groups_by_user_id[student.id] << group
      end
    end
    
    group
  end
  
  def create_student(search_key, course_instance)
    if search_key.include?('@')
      student = User.where(:email => search_key).first # TODO: Make case insensitive
      unless student
        student = User.new(:email => search_key, :firstname => '', :lastname => '')
        student.organization_id = course_instance.course.organization_id
        student.save(:validate => false)
      end
    else
      relation = User.where(:studentnumber => search_key)
      relation = relation.where(:organization_id => course_instance.course.organization_id) if course_instance.course.organization_id
      student = relation.first
      
      unless student
        student = User.new(:firstname => '', :lastname => '')
        student.organization_id = course_instance.course.organization_id
        student.studentnumber = search_key
        
        if course_instance.submission_policy == 'lti'
          student.lti_consumer = course_instance.course.organization.domain
          student.lti_user_id = search_key
        end

        student.save(:validate => false)
      end
    end
    
    if student
      course_instance.students << student  # Add student to course
      @students_by_studentnumber[student.studentnumber.strip.downcase] = student if student.studentnumber
      @students_by_lti_user_id[student.lti_user_id.strip]              = student if student.lti_user_id
      @students_by_email[student.email.strip.downcase]                  = student if student.email
    end
    
    student
  end
  
  def upload_submissions(exercise, io)
    # Make a temp directory
    t = Time.now.strftime("%Y%m%d%H%M%S")
    temp_dir = TMP_PATH + "/rubyric-#{exercise.id}-#{t}"
    
    # Determine file format
    case io.original_filename
    when /\.zip$/
      file_format = '.zip'
      archive_filename = temp_dir + file_format
      unzip_command = "unzip #{archive_filename} -d #{temp_dir}"
    when /\.tar\.gz$/
      file_format = '.tar.gz'
      archive_filename = temp_dir + file_format
      unzip_command = "tar xzf #{archive_filename} -C #{temp_dir}"
    when /\.tar.\bz2$/
      file_format = '.tar.bz2'
      archive_filename = temp_dir + file_format
      unzip_command = "tar xjf #{archive_filename} -C #{temp_dir}"
    else
      raise "Unsupported file format (must be .zip, .tar.gz or .tar.bz2)"
    end
    
    # Save the uploaded file
    File.open(archive_filename, 'wb') do |file|
      file.write(io.read)
    end
    
    Dir.mkdir(temp_dir)
    
    # Extract the archive
    system(unzip_command)
    
    # Create submissions
    failed_groups = []
    extract_files(temp_dir, exercise, failed_groups)
    
    # Delete the temporary directory
    FileUtils.rm_r(temp_dir)
    FileUtils.rm(archive_filename)
    
    failed_groups
  end
  
  def extract_files(dir, exercise, failed_groups)
    submissions_path = "#{SUBMISSIONS_PATH}/#{exercise.id}"
    FileUtils.makedirs(submissions_path)
    
    Dir.foreach(dir) do |item|
      next if item == '.' || item == '..'
      path = "#{dir}/#{item}"
      
      if File.directory?(path)
        # Descend to subdirectories
        extract_files(path, exercise, failed_groups)
      else
        # Create submission
        index = item.rindex('.') || item.length
        basename = item[0...index]
        
        # Find or create group
        group = find_or_create_group([basename], exercise.course_instance, {allow_empty_groups: true})
        
        if group
          submission = Submission.new(:exercise_id => exercise.id, :group_id => group.id)
          submission.authenticated = true
          submission.filename = item
          submission.extension = item.split('.').last
          submission.save(:validate => false)
          FileUtils.cp(path, "#{submissions_path}/#{submission.id}.#{submission.extension}")
        else
          failed_groups << item 
        end
      end
    end
  end
  
  
end
