require 'ims/lti'
require 'oauth/request_proxy/rack_request'

class LtisController < ApplicationController
  def tool
    return unless authorize_lti

#     signature = OAuth::Signature.build(request, :consumer_secret => @tp.consumer_secret)
#     logger.debug "SIGNATURE_BASE_STRING: #{signature.signature_base_string}"
#     logger.debug "SECRET: #{signature.send(:secret)}"
    # @tp.lti_msg = "Sorry that tool was so boring"
    
    # TODO:
    # add lticontext column to exercise
    # add lticontext to exercise settings form
    
    @exercise = Exercise.find_by_(params[:context_id])
    load_course
    I18n.locale = @course_instance.locale || I18n.locale
    @user = nil # todo later: load user
    
    @is_teacher = false # @course.has_teacher(current_user) # todo later: check role
    
    # todo later: Check that instance is active
    
    # Find groups that the user is part of
    @available_groups = []

    # Select group
    @group = nil
    
    @submissions = []

    @submission = Submission.new
    log "lti submit view #{@exercise.id}"
  end
 
  private
  
  
end
