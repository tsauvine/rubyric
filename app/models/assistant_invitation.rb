class AssistantInvitation < Invitation
  belongs_to :target, :class_name => 'CourseInstance'
  
  def accept(user)
    course_instance = CourseInstance.find(self.target_id)
    course_instance.assistants << user unless course.assistants.include?(user)
    self.destroy
  end
end
