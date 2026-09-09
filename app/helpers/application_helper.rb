module ApplicationHelper
  def active_if(*controllers)
    controllers = controllers.map { |c| c.to_s }
    " active" if controllers.include?(controller.controller_name)
  end

  def visible?(*controllers)
    controllers = controllers.map { |c| c.to_s }
    controllers.include?(controller.controller_name)
  end

  def icon_and_text(icon_name, text)
    content_tag(:span, class: "d-flex") do
      concat content_tag(:i, "", class: "bi bi-#{icon_name} me-1")
      concat text
    end
  end

  def entity_type_badge(entity)
    type_name = entity.class.name.demodulize.underscore
    type = entity.send("#{type_name}_type").name
    content_tag(:span, type.titleize, class: "badge bg-info text-dark ms-2")
  end
end
