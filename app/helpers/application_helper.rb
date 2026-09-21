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

  def icon(name)
    content_tag(:i, "", class: "bi bi-#{name} me-1")
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

    if entity_class_name.ends_with?("_type")
      return type_badge(entity)
    end

    association_name = "#{entity_class_name}_types"
    return unless entity.respond_to?(association_name)

    safe_join(entity.send(association_name).map { |type| type_badge(type) }, " ")
  end

  private

  def type_badge(type)
    bgcolor = type.respond_to?(:bgcolor) ? type.bgcolor : "#d3d3d3"
    fgcolor = type.respond_to?(:fgcolor) ? type.fgcolor : "#000000"
    content_tag(:span, type.name,
      class: "badge text-dark",
      style: "background-color: #{bgcolor} !important; color: #{fgcolor} !important;"
    )
  end
end
