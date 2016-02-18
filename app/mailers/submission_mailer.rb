class SubmissionMailer < ActionMailer::Base
  def receive(email)
    logger.info "Receiving mail from #{email.to}, subject #{email.subject}"
    
    if email.has_attachments?
      email.attachments.each do |attachment|
        logger.info "Attachment:"
        logger.info attachment
      end
    end
  end
end
