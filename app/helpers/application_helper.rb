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

  # Universe authorization and this helper must resolve a record's Universe the
  # same way, or a writer sees missing controls while a record-level check
  # denies an allowed mutation. Both use the shared resolver.
  def universe_for_record(record)
    UniverseScopeResolver.universe_for(record)
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

  # One labelled value in a details page's identity block. A missing value
  # renders explicit copy instead of a blank row, and the copy is per-fact so a
  # page never implies a value it does not have.
  def detail_fact(label, value, blank: "Not set yet.")
    { label: label, value: value.presence || blank }
  end

  # One in-world interval, for the details pages of Event, Relation, and
  # Ownership. All three store an optional pair of datetimes, and an open or
  # absent bound is stated as such instead of being hidden or guessed.
  def in_world_range(from, to, empty: "No dates set yet.")
    from_label = from&.strftime(DATE_FORMAT)
    to_label = to&.strftime(DATE_FORMAT)

    return empty if from_label.blank? && to_label.blank?
    return "From #{from_label}" if to_label.blank?
    return "Until #{to_label}" if from_label.blank?

    "#{from_label} – #{to_label}"
  end

  DATE_FORMAT = "%Y-%m-%d %H:%M"

  # The one "Details" link used by every record's list row and taxonomy node.
  # It is real navigation to that record's own page, so it renders for read-only
  # members and guests too, and it never hides behind a hover-only action menu.
  #
  # `count` is the number of related records the destination will list. It is
  # part of the visible label — "Details (10 characters)" — because the count is
  # what makes a taxonomy scannable, and it is repeated in the accessible name
  # together with the record name so many identical-looking links stay
  # distinguishable in a long list.
  def record_details_link(path, record:, count: nil, count_label: "item", classes: %w[details-link])
    summary = count.nil? ? nil : "(#{pluralize(count, count_label)})"
    record_name = record.try(:display_string) || record.try(:name) || record.to_s
    accessible_name = [ "Details for #{record_name}", summary ].compact.join(" ")

    link_to path, class: classes.join(" "), aria: { label: accessible_name } do
      concat content_tag(:i, "", class: "bi bi-box-arrow-up-right", aria: { hidden: true })
      concat content_tag(:span, "Details")
      # The leading space keeps the visible label readable as "Details (3 items)".
      concat content_tag(:span, " #{summary}", class: "details-link-count") if summary
    end
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
