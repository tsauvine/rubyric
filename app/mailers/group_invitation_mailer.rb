class GroupInvitationMailer < ActionMailer::Base
  default :from => RUBYRIC_EMAIL
  default_url_options[:host] = RUBYRIC_HOST
  
  def invitation(invitation_id)
    @invitation = GroupInvitation.find(invitation_id)
    
    @group = @invitation.group
    @course_instance = @group.course_instance
    @course = @course_instance.course
    
    subject = "#{@course.code} #{@course.name} - Join group"
    
    mail(:to => @invitation.email, :subject => subject)
  end
  
end
