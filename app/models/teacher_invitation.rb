class TeacherInvitation < Invitation
  belongs_to :target, :class_name => 'Course'
  
  def accept(user)
    course = Course.find(self.target_id)
    course.teachers << user unless course.teachers.include?(user)
    self.destroy
  end
end
