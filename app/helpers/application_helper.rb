module ApplicationHelper
  def active_if(*controllers)
    controllers = controllers.map { |c| c.to_s }
    " active" if controllers.include?(controller.controller_name)
  end

  def visible?(*controllers)
    controllers = controllers.map { |c| c.to_s }
    controllers.include?(controller.controller_name)
  end
end
