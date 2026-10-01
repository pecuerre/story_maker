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

  # The appearance this request renders with. It comes from a signed cookie
  # rather than from `Current`, because it is a property of the browser and not
  # of the session, universe, or story the request happens to carry. Memoized for
  # the render: the layout and the settings form must not disagree.
  def current_theme
    @current_theme ||= AppTheme.read(cookies)
  end

  # The language this request renders in. Read from the same kind of signed
  # cookie as the theme, and therefore subject to the same "unknown value is the
  # default" rule. `I18n.locale` is already set from this by
  # `ApplicationController#switch_locale`; the helper exists so a view can ask
  # what it is without reaching into `I18n` directly, and so the settings form
  # and the layout cannot disagree about it.
  def current_locale
    @current_locale ||= AppLocale.read(cookies)
  end

  # Where this reader is sent when they sign in with nothing to return to. Read
  # from a signed cookie for the same reason as the theme and the language, and
  # therefore subject to the same "unknown value is the default" rule.
  def current_start_page
    @current_start_page ||= AppStartPage.read(cookies)
  end

  # The settings sections, in the order the vertical navigation lists them. Each
  # one owns a real destination, so the navigation is URL-backed like every other
  # tab strip in the application: no `data-bs-toggle`, no in-document panes. The
  # first section owns the page's own URL (`/settings`) rather than a query
  # parameter, so one section does not have two addresses; a later section that
  # needs its own state gets `?section=…`, which is that own state rather than a
  # second route for the same page.
  #
  # Adding a section is one entry here, one in `SETTINGS_SECTIONS`, and one panel
  # in the view — the sections are a list rather than a pair of booleans for
  # exactly that reason.
  SETTINGS_SECTIONS = %w[appearance language start_page].freeze

  def settings_tabs
    [
      { label: t("settings.tabs.appearance"), icon: "palette", path: settings_path,
        active: settings_section?("appearance") },
      { label: t("settings.tabs.language"), icon: "translate", path: settings_path(section: "language"),
        active: settings_section?("language") },
      { label: t("settings.tabs.start_page"), icon: "box-arrow-in-right", path: settings_path(section: "start_page"),
        active: settings_section?("start_page") }
    ]
  end

  # Which settings section this request is showing. The query parameter is the
  # only thing that distinguishes them, so the navigation, the panel, and the
  # redirect after a save all read this one answer. An absent or unrecognised
  # parameter is the first section, which is the page's own address — so
  # `/settings` and `/settings?section=nonsense` are the same page rather than an
  # error.
  def current_settings_section
    requested = params[:section].to_s
    SETTINGS_SECTIONS.include?(requested) ? requested : SETTINGS_SECTIONS.first
  end

  def settings_section?(name)
    current_settings_section == name.to_s
  end

  def settings_path_for(section)
    section == SETTINGS_SECTIONS.first ? settings_path : settings_path(section: section)
  end

  def icon(name)
    content_tag(:i, "", class: "bi bi-#{name}")
  end

  # A sidebar link's content: an icon, a visible label, and an optional count
  # pill. The pill's accessible name is the *record type* in the plural, which
  # is why `count_label` is an I18n key rather than the visible `text`: the
  # visible label may read "Ownerships" while the count is announced as
  # "ownerships", and neither is derived from the other.
  def icon_text_count(icon, text, count = nil, count_label: nil)
    content_tag(:span, class: "sidebar-link-content d-flex align-items-center gap-2 w-100") do
      concat content_tag(:i, "", class: "bi bi-#{icon}", aria: { hidden: true })
      concat content_tag(:span, text, class: "sidebar-link-label")
      unless count.nil?
        concat content_tag(:span, count,
          class: "sidebar-count",
          aria: { label: t(count_label || text, count: count) })
      end
    end
  end

  # Stories listed on the universe page, so that page can be the story picker
  # without paying for a second query. Memoized per request; the top bar no
  # longer needs a list of its own.
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
    when "admin" then t("universe_access.admin")
    when "write" then t("universe_access.contributor")
    when "read" then t("universe_access.read_only")
    else universe.private? ? t("universe_access.none") : t("universe_access.public_read_only")
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

  # A record's stored photo, as a URL an editor can show before a replacement is
  # chosen, or nothing. An Active Storage attachment's URL is built by the
  # request serving it, so this is a view helper rather than a model method; a
  # record that has no photo — the normal case — is simply `nil`.
  def record_photo_url(record)
    photo = record&.photo
    return if photo.blank?

    url_for(photo.file)
  end

  # One labelled value in a details page's identity block. A missing value
  # renders explicit copy instead of a blank row, and the copy is per-fact so a
  # page never implies a value it does not have.
  def detail_fact(label, value, blank: nil)
    { label: label, value: value.presence || blank || t("shared.detail_fact.blank") }
  end

  # One in-world interval, for the details pages of Event, Relation, and
  # Ownership. All three store an optional pair of datetimes, and an open or
  # absent bound is stated as such instead of being hidden or guessed.
  def in_world_range(from, to, empty: nil)
    from_label = from&.strftime(DATE_FORMAT)
    to_label = to&.strftime(DATE_FORMAT)

    return empty || t("shared.in_world_range.empty") if from_label.blank? && to_label.blank?
    return t("shared.in_world_range.from", date: from_label) if to_label.blank?
    return t("shared.in_world_range.until", date: to_label) if from_label.blank?

    "#{from_label} – #{to_label}"
  end

  DATE_FORMAT = "%Y-%m-%d %H:%M"

  # The value a `datetime-local` editor control has to carry, which is a stored
  # value rather than a display one: `DATE_FORMAT` above is what a *reader* is
  # shown, while this is what the browser is handed so that opening an editor and
  # saving it again round-trips the column instead of quietly rewriting it. It
  # keeps seconds for that reason, and every control that follows this contract
  # also carries `step: 1`, because a control whose step is a whole minute
  # cannot hold a second even when the value it is given has one.
  DATETIME_LOCAL_FORMAT = "%Y-%m-%dT%H:%M:%S"

  # The one "Details" link used by every record's list row and taxonomy node.
  # It is real navigation to that record's own page, so it renders for read-only
  # members and guests too, it sits on the right of the row next to the actions,
  # and it never hides behind a hover-only menu.
  #
  # The link carries no count. A count is a fact about the record rather than
  # about its destination, so it renders next to the name and tags as
  # `record_count_badge` and the link label stays short in a long list.
  def record_details_link(path, record:, classes: %w[details-link])
    link_to path, class: classes.join(" "), aria: { label: t("shared.record_details_link.aria", name: record_label(record)) } do
      concat content_tag(:i, "", class: "bi bi-box-arrow-up-right", aria: { hidden: true })
      concat content_tag(:span, t("shared.record_details_link.text"))
    end
  end

  # How a record is named wherever a shared partial has to name it without
  # knowing the model: a row action's delete confirmation, a record's own details
  # page, a taxonomy page's list of what carries a tag.
  #
  # `#display_label` first, because that is a `#display_string` whose chrome has
  # been resolved in the reader's language. Only the models whose label *is* a
  # sentence define it — `Event` and `Ownership` today — and a `#display_string`
  # that is the author's own words or a neutral pair (`Relation`) is already the
  # same in every language, so it needs no second form. This is the one place
  # that order is written, because five shared partials reading it separately is
  # how a row and its own page end up disagreeing about a record's name.
  def record_label(record)
    record.try(:display_label) || record.try(:display_string) || record.try(:name) || record.to_s
  end

  # A count and the record type it counts, as one phrase: "3 characters".
  #
  # `label` is an I18n key, not a finished noun. Every workspace already passes a
  # bare word here (`count_label: "character"`, `details_count_label: "scene"`),
  # and those words are the keys defined at the root of the locale files, so the
  # plural is chosen by the locale instead of by appending an "s" here. That is
  # the only reason the record-type nouns sit at the root rather than under
  # `shared`: a caller passes the same key to `page_header`, to a taxonomy tree,
  # and to a count badge, and all of them resolve it the same way.
  def count_with_label(count, label = "item")
    t("shared.count.with_count", count: count, label: t(label, count: count))
  end

  # The number of related records a record's own page will list: "(4
  # characters)". The label is part of the text, so a bare figure is never
  # ambiguous in a list of many rows.
  def record_count_text(count, label = "item")
    "(#{count_with_label(count, label)})"
  end

  # That count as a left-aligned pill next to the name and its tag badges. It is
  # never part of the Details link, and the visible text is its own accessible
  # name, so nothing is announced twice. A nil count (a page with nothing to
  # list) renders nothing rather than a zero.
  def record_count_badge(count, label = "item")
    return if count.nil?

    content_tag(:span, record_count_text(count, label), class: "record-count")
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
