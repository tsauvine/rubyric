module ApplicationHelper

  # Returns 'active' if current controller and action match parameters. Otherwise, returns an empty string.
  # e.g. active_nav('course', 'show')
  def active_nav(target_controller, target_action)
    puts "*****************"
    puts controller.controller_name
    puts controller.action_name
    controller.controller_name == target_controller && controller.action_name == target_action ? 'active' : ''
  end

end
