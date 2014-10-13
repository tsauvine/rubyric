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
    
    @exercise = Exercise.find_by_lticontext(params[:context_id])
    load_course
    I18n.locale = @course_instance.locale || I18n.locale
    
    @is_teacher = false # @course.has_teacher(current_user) # todo later: check role
    
    # TODO: create user, group and groupmember
    params[:user_id]
    
    @user = nil # todo later: load user
    @group = nil
    
    # todo later: Check that instance is active
    
    # Find groups that the user is part of
    @available_groups = []

    # Select group
    @submissions = []

    @submission = Submission.new
    log "lti submit view #{@exercise.id}"
  end
 
  private
  
    
  def authorize_lti
    key = params['oauth_consumer_key']
    
    unless key
      @heading =  "No consumer key"
      render :template => "shared/error"
      return false
    end
    
    secret = OAUTH_CREDS[key]
    unless secret
      @tp = IMS::LTI::ToolProvider.new(nil, nil, params)
      @tp.lti_msg = "Your consumer didn't use a recognized key."
      @tp.lti_errorlog = "You did it wrong!"
      @heading =  "Consumer key wasn't recognized"
      render :template => "shared/error"
      return false
    end
    
    @tp = IMS::LTI::ToolProvider.new(key, secret, params)
    
    unless @tp.valid_request?(request)
      @heading =  "The OAuth signature was invalid"
      render :template => "shared/error"
      return false
    end
    
    if Time.now.utc.to_i - @tp.request_oauth_timestamp.to_i > 60*60
      @heading =  "Your request is too old."
      render :template => "shared/error"
      return false
    end
    
    if was_nonce_used_in_last_x_minutes?(@tp.request_oauth_nonce, 60)
      @heading =  "Why are you reusing the nonce?"
      render :template => "shared/error"
      return false
    end
    
    @username = @tp.username("Dude")
    return true
  end
  
  def was_nonce_used_in_last_x_minutes?(nonce, minutes=60)
    # some kind of caching solution or something to keep a short-term memory of used nonces
    false
  end
end
