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
  
  def video_player(url)
    url = "https://aalto.cloud.panopto.eu/Panopto/Podcast/Stream/ab0ad6a2-bd80-42cb-a29e-49ec3cc677ec.mp4?mediaTargetType=videoPodcast"
    
    video_id = /[\w-]*.mp4/.match(url)
    unless video_id
      return ''
    end
    
    html = "
<video controls='' width='640px'>
  <source src='https://aalto.cloud.panopto.eu/Panopto/Podcast/Stream/#{video_id}?mediaTargetType=videoPodcast' type='video/mp4'></source>
  Your browser does not support the video tag.
</video>".html_safe
  end
end
