module ApplicationHelper

  # Returns 'active' if current controller and action match parameters. Otherwise, returns an empty string.
  # e.g. active_nav('course', 'show')
  def active_nav(target_controller, target_action)
    controller.controller_name == target_controller && controller.action_name == target_action ? 'active' : ''
  end

  def reviewer_name(review)
    if @exercise && @exercise.anonymous_graders
      t 'anonymous_review'
    elsif review.user
      review.user.name
    else
      t 'collaborative_review'
    end
  end
  
  def video_player(url = '', width = 640)
    stripped_url = url.strip
    if stripped_url.blank?
      return ''
    end
    
    # Panopto  
    if stripped_url.downcase =~ /^(https?:\/\/.*panopto)/
      video_id = nil
      
      match = /([\w-]*).mp4$/.match(stripped_url)
      video_id = match.captures.first if match
        
      unless match
        match = /id=([\w-]*)$/.match(stripped_url)
        video_id = match.captures.first if match
      end
      
      if video_id
        #return "<video controls='' width='#{width}px'>
#<source src='https://aalto.cloud.panopto.eu/Panopto/Podcast/Stream/#{video_id}.mp4?mediaTargetType=videoPodcast' type='video/mp4'></source>
#Your browser does not support the video tag.
#</video>".html_safe
        return "<iframe src='https://aalto.cloud.panopto.eu/Panopto/Pages/Embed.aspx?id=#{video_id}&v=1' width='#{width}' height='#{(width * 0.5625).floor}' style='padding: 0px;' frameborder='0' webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>".html_safe
      else
        return ''
      end
    end
    
    # Long Youtube URL
    if stripped_url.downcase =~ /^https?:\/\/www\.youtube\.com\/watch/
      match = /v=([\w-]*)/.match(stripped_url)
      return '' unless match
      video_id = match.captures.first
      if video_id
        return "<iframe type='text/html' width='#{width}' height='#{(width * 0.5625).floor}'
src='https://www.youtube.com/embed/#{video_id}?autoplay=0&origin=#{RUBYRIC_HOST}'
frameborder='0' webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>".html_safe
      else
        return ''
      end
    end
    
    # Short Youtube URL
    if stripped_url.downcase =~ /^https?:\/\/youtu\.be\//
      match = /([\w-]*)$/.match(stripped_url)
      return '' unless match
      video_id = match.captures.first
      if video_id
        return "<iframe type='text/html' width='#{width}' height='#{(width * 0.5625).floor}'
src='https://www.youtube.com/embed/#{video_id}?autoplay=0&origin=#{RUBYRIC_HOST}'
frameborder='0' webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>".html_safe
      else
        return ''
      end
    end
    
    return ''
  end
end
