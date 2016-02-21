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
end
