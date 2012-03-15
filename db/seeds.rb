# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Major.create(:name => 'Daley', :city => cities.first)

# Create admin
user = User.new(:password => 'admin', :password_confirmation => 'admin', :firstname => 'Admin', :lastname => 'User', :email => '')
user.login = 'admin'
user.studentnumber = 'admin'
user.admin = true
user.save

# Create teachers
for i in 1..2 do
  r = User.new
  r.studentnumber = '1' + i.to_s.rjust(4, '0')
  r.login = r.studentnumber
  r.password = "teacher#{i}"
  r.password_confirmation = "teacher#{i}"
  r.firstname = 'Teacher'
  r.lastname = i
  r.email = "teacher#{i}@example.com"
  r.save
end


# Create students
for i in 1..10 do
  r = User.new
  r.studentnumber = i.to_s.rjust(5, '0')
  r.login = r.studentnumber
  r.password = "student#{i}"
  r.password_confirmation = "student#{i}"
  r.firstname = 'Student'
  r.lastname = i
  r.email = "student#{i}@example.com"
  r.save
end

# Create assistants
for i in 11..20 do
  r = User.new
  r.studentnumber = i.to_s.rjust(5, '0')
  r.login = r.studentnumber
  r.firstname = 'Assistant'
  r.lastname = i
  r.email = "assistant#{i}@example.com"
  r.password = "assistant#{i}"
  r.password_confirmation = "assistant#{i}"
  r.save
end


# Create courses
course = Course.create(:code => '0.101', :name => 'Test')
instance = CourseInstance.create(:name => 'Spring 2012', :course => course)
exercise = Exercise.create(:name => 'Exercise 1', :course_instance => instance)
