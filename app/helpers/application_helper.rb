module ApplicationHelper
  def active_if(*controllers)
    controllers = controllers.map { |c| c.to_s }
    " active" if controllers.include?(controller.controller_name)
  end

  def visible?(*controllers)
    controllers = controllers.map { |c| c.to_s }
    controllers.include?(controller.controller_name)
    true
  end

  def icon_text_count(icon, text, count = nil)
    content_tag(:span, class: "d-flex") do
      concat content_tag(:i, "", class: "bi bi-#{icon} me-1")
      concat text
      if count.present?
        # concat content_tag(:span, count, class: "badge text-bg-secondary rounded-pill ms-1")
        concat content_tag(:small, "(#{count})", class: "text-body-secondary")
      end
    end
  end

  def entity_type_badge(entity)
    return if entity.nil?
    type_name = entity.class.name.demodulize.underscore
    return unless entity.respond_to?("#{type_name}_type")
    type = entity.send("#{type_name}_type").name
    content_tag(:span, type, class: "badge bg-info text-dark")
  end
end
