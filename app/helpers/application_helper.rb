module ApplicationHelper
  def active_if(*controllers)
    controllers = controllers.map { |controller| controller.to_s }
    " active" if controllers.include?(controller.controller_name)
  end

  def aria_current_for(*controllers)
    controllers = controllers.map { |controller| controller.to_s }
    controllers.include?(controller.controller_name) ? { current: "page" } : {}
  end

  def visible?(*controllers)
    controllers = controllers.map { |controller| controller.to_s }
    controllers.include?(controller.controller_name)
  end

  def icon(name)
    content_tag(:i, "", class: "bi bi-#{name}")
  end

  def icon_text_count(icon, text, count = nil)
    content_tag(:span, class: "sidebar-link-content d-flex align-items-center gap-2 w-100") do
      concat content_tag(:i, "", class: "bi bi-#{icon}", aria: { hidden: true })
      concat content_tag(:span, text, class: "sidebar-link-label")
      unless count.nil?
        concat content_tag(:span, count,
          class: "sidebar-count",
          aria: { label: pluralize(count, text) })
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

    @nav_stories ||= Current.universe.stories.order(:id).to_a
  end

  def can_read_universe?(universe = Current.universe)
    universe.present? && current_ability.can?(:read, universe)
  end

  def can_write_universe?(universe = Current.universe)
    universe.present? && current_ability.can?(:write, universe)
  end

  def can_administer_universe?(universe = Current.universe)
    universe.present? && current_ability.can?(:admin, universe)
  end

  def universe_access_level(universe = Current.universe)
    current_ability.access_level_for(universe)
  end

  def universe_access_label(universe = Current.universe)
    return nil if universe.nil?

    case universe_access_level(universe)
    when "admin" then "Admin"
    when "write" then "Contributor"
    when "read" then "Read-only"
    else universe.private? ? "No access" : "Public read-only"
    end
  end

  def universe_for_record(record)
    return if record.nil?
    return record.universe if record.respond_to?(:universe)
    return record.story.universe if record.respond_to?(:story) && record.story

    nil
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
        class: "badge rounded-pill taxonomy-tag text-dark",
        style: "background-color: #{bgcolor} !important; color: #{fgcolor} !important;"
      )
    end
end
