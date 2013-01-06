class InvitationMailer < ActionMailer::Base
  default :from => RUBYRIC_EMAIL
  default_url_options[:host] = RUBYRIC_HOST
  
  def group_invitation(invitation_id)
    @invitation = GroupInvitation.find(invitation_id)
    
    @group = @invitation.group
    @course_instance = @group.course_instance
    @course = @course_instance.course
    
    subject = "#{@course.code} #{@course.name} - Join group"
    
    mail(:to => @invitation.email, :subject => subject)
  end
  
  
  def teacher_invitation(invitation_id)
    @invitation = Invitation.find(invitation_id)
    @course = Course.find(@invitation.target_id)
    
    subject = "#{@course.code} #{@course.name} - Rubyric instructor access"
    mail(:to => @invitation.email, :subject => subject)
  end

  
  def assistant_invitation(invitation_id)
    @invitation = Invitation.find(invitation_id)
    @course_instance = CourseInstance.find(@invitation.target_id)
    @course = @course_instance.course
    
    subject = "#{@course.code} #{@course.name} - Rubyric reviewer access"
    mail(:to => @invitation.email, :subject => subject)
  end
  
end
