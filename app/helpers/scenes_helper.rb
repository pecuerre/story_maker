# Scene-specific descriptors for the stable HTML editor and the grouping
# workspace, plus the two answers every Scene participation surface shares. Scene
# JSON is not used: the Scene flow keeps the HTML
# redirect/re-render responsibility, and the JSON+Stimulus responsibility stays
# with the Element and presence-link flows added in later slices.
module ScenesHelper
  # The Section group of a Scene, or nil when it is ungrouped. Grouping is
  # organization only, so this is never used to derive an order.
  def scene_grouping_label(scene, section_paths)
    section_paths.label_for(scene.section_id)
  end

  # The same label for a group heading, where a nil id is the Ungrouped group
  # rather than an unknown Section. The word comes from `SectionPaths` rather
  # than from this helper, so the Section selector and this heading cannot
  # disagree about what the group is called.
  def scene_grouping_label_by_id(section_paths, section_id)
    section_paths.label_for(section_id) || section_paths.ungrouped_label
  end

  # [ label, value ] pairs for a picker of universe records, in the order it is
  # given.
  #
  # The label is the author's own record name and the value is the record id, so
  # neither is translated. `[ label, value ]` is Rails' own order and the reverse
  # of what a `data-*` pair or a serialized hash looks like, which is why the three
  # Scene pickers that offer a flat list share one method rather than three
  # spellings: a reversed pair still renders a full-looking dropdown and submits
  # the wrong value, and a name sent where an id belongs fails the model's
  # reference validation rather than selecting the wrong row.
  def name_id_choices(records)
    records.map { |record| [ record.name, record.id ] }
  end

  # The free-text role as a Scene row states it, or the honest statement that the
  # author recorded the appearance without saying how.
  #
  # A blank role is a real state, not a missing value, so it is stated rather than
  # rendered as an empty cell. Only the fallback sentence is chrome: the role
  # itself is the author's own words and is returned unchanged.
  #
  # This has one home because four surfaces answer the same question — the
  # Characters, Items, and Locations tabs, and the "Appears in Scenes" section on a
  # record's own details page — and a Character linked in one of them and the same
  # Character on another page have to be described identically. Both entry types
  # answer `#role`, which is the only thing this reads.
  #
  # It takes no view of *why* a row exists. `SceneAppearances::Entry` calls it only
  # for a stored link, because a derived speaker and a depicted Event never carry
  # a role at all; the three tabs have no such row to confuse.
  def scene_role_label(entry)
    entry.role.presence || t("scenes.participation.no_role")
  end

  # [ label, value ] pairs in Rails' select order: an explicit **None** first,
  # then the universe's events. Several Scenes may pick the same Event, so this
  # is a plain single-select rather than an exclusion list.
  #
  # The blank option's *value* is the empty string the form stores and the rest
  # are event ids, so neither is translated; only the blank's own label and the
  # events' own labels are chrome. An event's own label is `display_label` rather
  # than the `display_string` a search document stores, so a Scene's event picker
  # reads in the reader's language.
  def scene_event_choices(events)
    [ [ t("shared.none"), "" ] ] + events.map { |event| [ event.display_label, event.id ] }
  end

  # The Scene's own in-world time point, formatted with the same minute
  # precision as the event datetimes. It is deliberately not derived from the
  # linked Event.
  def scene_in_world_time(scene)
    return if scene.datetime.blank?

    scene.datetime.strftime("%Y-%m-%d %H:%M")
  end

  # [ label, value ] pairs for the optional Scene Tag selector. The path is
  # built from the already-loaded Story list so a nested tag does not trigger a
  # parent query for every checkbox/option.
  def scene_tag_choices(tags, paths = SceneTagPaths.build(tags))
    paths.choices.presence || tags.map { |tag| [ paths.label_for(tag) || tag.name, tag.id ] }
  end

  # What the datetime-local field must render. A rejected value is kept as the
  # author typed it, so a validation error never silently clears the input. A
  # stored value keeps its seconds, so opening this form and saving it again
  # round-trips the column instead of rewriting it to zero seconds.
  def scene_datetime_field_value(scene)
    return scene.datetime.strftime(ApplicationHelper::DATETIME_LOCAL_FORMAT) if scene.datetime.present?

    raw = scene.read_attribute_before_type_cast(:datetime)
    raw.is_a?(String) ? raw : nil
  end

  # "Label: value" descriptions of the filters currently in effect, in the order
  # the search area lists them. The result set of a long story is otherwise
  # ambiguous, and an empty result has to be able to say what caused it.
  #
  # Each entry is its own key rather than one frame with the field name
  # interpolated, because "In-world from 2026-09-11" is a different sentence in
  # each language than "Section: <path>" is.
  def scene_filter_summaries(filter, section_paths, scene_tag_paths)
    summaries = []
    summaries << t("scenes.filter.summaries.search", value: filter.text) if filter.text.present?
    if filter.ungrouped?
      summaries << t("scenes.filter.summaries.section", value: section_paths.ungrouped_label)
    elsif filter.section_id
      summaries << t("scenes.filter.summaries.section", value: section_paths.label_for(filter.section_id))
    end
    if filter.scene_tag
      summaries << t("scenes.filter.summaries.scene_tag", value: scene_tag_paths.label_for(filter.scene_tag))
    end
    summaries << t("scenes.filter.summaries.from", value: filter.from_date.iso8601) if filter.from_date
    summaries << t("scenes.filter.summaries.to", value: filter.to_date.iso8601) if filter.to_date
    summaries
  end
end
