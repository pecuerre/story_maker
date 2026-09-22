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

  # Universes listed in the top bar dropdown, respecting visibility rules.
  def nav_universes
    @nav_universes ||= Universe.visible_to(Current.user).order(:name)
  end

  # Stories listed in the top bar dropdown of the current universe.
  def nav_stories
    return [] if Current.universe.nil?

    @nav_stories ||= Current.universe.stories.order(:id)
  end

  def entity_tag_badge(entity)
    return if entity.nil?

    entity_class_name = entity.class.name.demodulize.underscore

    if entity_class_name.ends_with?("_tag")
      return tag_badge(entity)
    end

    association_name = "#{entity_class_name}_tags"
    return unless entity.respond_to?(association_name)

    safe_join(entity.send(association_name).map { |tag| tag_badge(tag) }, " ")
  end

  private

  def tag_badge(tag)
    bgcolor = tag.respond_to?(:bgcolor) ? tag.bgcolor : "#d3d3d3"
    fgcolor = tag.respond_to?(:fgcolor) ? tag.fgcolor : "#000000"
    content_tag(:span, tag.name,
      class: "badge text-dark",
      style: "background-color: #{bgcolor} !important; color: #{fgcolor} !important;"
    )
  end
end
