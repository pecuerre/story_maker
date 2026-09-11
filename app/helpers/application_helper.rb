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

    entity_class_name = entity.class.name.demodulize.underscore
    entity_class_type_name = "#{entity_class_name}_type"

    if entity_class_name.ends_with?("_type")
      entity_type = entity
      badge = entity.name
    elsif entity.respond_to?(entity_class_type_name)
      entity_type = entity.send("#{entity_class_type_name}")
      badge = entity.send("#{entity_class_type_name}").name
    else
      return
    end

    color = entity_type.respond_to?(:color) ? entity_type.color : "#d3d3d3"
    content_tag(:span, badge, class: "badge text-dark", style: "background-color: #{color};")
  end
end
