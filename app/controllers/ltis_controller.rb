require 'ims/lti'
require 'oauth/request_proxy/rack_request'


# aplus
# resource_link_id: harjoitus1
# context_id: ohjelmointi1


class LtisController < ApplicationController
  def tool
    return unless authorize_lti

    @exercise = Exercise.where(:lti_consumer => params['oauth_consumer_key'], :lti_context_id => params[:context_id]).first
    unless @exercise
      @heading =  "This course is not configured"
      render :template => "shared/error"
      return
    end
    
    load_course
    I18n.locale = @course_instance.locale || I18n.locale
    
    #@user = nil
    #@is_teacher = false # @course.has_teacher(current_user) # todo later: check role
    
    # TODO: create user, group and groupmember
    # Find user
    GroupMember.where(:lti_consumer => params['oauth_consumer_key'], :lti_user_id => params[:user_id]).find_each do |member|
      member.group
    end
    
    unless @group
      groupname = 'untitled group' # TODO: groupname in LTI
      group = Group.new({:course_instance_id => @course_instance.id, :exercise_id => @exercise.id, :name => groupname})
      group.save(:validate => false)
    
      member = GroupMember.new(:email => params[:lis_person_contact_email_primary])
      member.group = @group
      member.save()
    end
    
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
