class InvitationMailer < ActionMailer::Base
  default :from => RUBYRIC_EMAIL
  default_url_options[:host] = RUBYRIC_HOST
  
  def group_invitation(group_member_id, exercise_id)
    @group_member = GroupMember.find(group_member_id)
    
    @group = @group_member.group
    @course_instance = @group.course_instance
    @course = @course_instance.course
    @exercise_id = exercise_id
    
    I18n.with_locale(@course_instance.locale || I18n.locale) do
      subject = t('invitation_mailer.group_invitation.subject', :course => "#{@course.full_name}")
      mail(:to => @group_member.email, :subject => subject)
    end
  end
  
  
  def teacher_invitation(invitation_id)
    @invitation = Invitation.find(invitation_id)
    @course = Course.find(@invitation.target_id)
    
    subject = "#{@course.full_name} - Rubyric instructor access"
    mail(:to => @invitation.email, :subject => subject)
  end

  
  def assistant_invitation(invitation_id)
    @invitation = Invitation.find(invitation_id)
    @course_instance = CourseInstance.find(@invitation.target_id)
    @course = @course_instance.course
    
    subject = "#{@course.full_name} - Rubyric reviewer access"
    mail(:to => @invitation.email, :subject => subject)
  end
  
end
