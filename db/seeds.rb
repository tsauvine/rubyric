puts "Creating example users and courses"

example_organization = Organization.create(:name => 'Example', :domain => 'example.com')

# Create admin
# user = User.new(:password => 'admin', :password_confirmation => 'admin', :firstname => 'Admin', :lastname => 'User', :email => 'admin@example.com')
# user.login = 'admin'
# user.studentnumber = '12345'
# user.admin = true
# user.save

# Example students
# user = User.new(:password => '45237357', :password_confirmation => '45237357', :firstname => "Student", :lastname => "1", :email => 'student.1@example.com')
# user.login = 'student-1'
# user.studentnumber = '123456'
# user.organization = example_organization
# user.save
#
# user = User.new(:password => '56724356', :password_confirmation => '56724356', :firstname => "Student", :lastname => "2", :email => 'student.2@example.com')
# user.login = 'student-2'
# user.studentnumber = '234567'
# user.organization = example_organization
# user.save

# Create courses
# example_courses = []
# for i in 1..2 do
#   course = Course.create(:code => "0.#{100 + i}", :name => 'Test')
#   instance = CourseInstance.create(:name => "Spring #{Time.now.year}", :course => course)
#   exercise = Exercise.create(:name => 'Exercise 1', :course_instance => instance)
#
#   example_courses[i] = course
# end

# Create teachers
# for i in 1..2 do
#   user = User.new
#   user.studentnumber = '1' + i.to_s.rjust(4, '0')
#   user.login = user.studentnumber
#   user.password = "teacher#{i}"
#   user.password_confirmation = "teacher#{i}"
#   user.firstname = 'Teacher'
#   user.lastname = i
#   user.email = "teacher#{i}@example.com"
#   user.organization = example_organization
#   user.save
#
#   if example_courses[i]
#     example_courses[i].teachers << user
#   end
# end


# Create students
for i in 1..500 do
  user = User.new
  user.studentnumber = i.to_s.rjust(5, '0')
  user.login = user.studentnumber
  user.password = "student#{i}"
#   user.password_confirmation = "student#{i}"
  user.firstname = 'Student'
  user.lastname = i.to_s
  user.email = "student#{i}@example.com"
  user.organization = example_organization
  user.save
end

# Create assistants
for i in 1..10 do
  user = User.new
  user.studentnumber = "1" + i.to_s.rjust(4, '0')
  user.login = user.studentnumber
  user.firstname = 'Assistant'
  user.lastname = i.to_s
  user.email = "assistant#{i}@example.com"
  user.password = "assistant#{i}"
#   user.password_confirmation = "assistant#{i}"
  user.organization = example_organization
  user.save
end

puts "Done"
