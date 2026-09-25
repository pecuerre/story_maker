# Scene-specific descriptors for the stable HTML editor and the grouping
# workspace. Scene JSON is not used: the Scene flow keeps the HTML
# redirect/re-render responsibility, and the JSON+Stimulus responsibility stays
# with the Element and presence-link flows added in later slices.
module ScenesHelper
  # The Section group of a Scene, or nil when it is ungrouped. Grouping is
  # organization only, so this is never used to derive an order.
  def scene_grouping_label(scene, section_paths)
    section_paths.label_for(scene.section_id)
  end

  # The same label for a group heading, where a nil id is the Ungrouped group
  # rather than an unknown Section.
  def scene_grouping_label_by_id(section_paths, section_id)
    section_paths.label_for(section_id) || SectionPaths::UNGROUPED_LABEL
  end

  # [ label, value ] pairs in Rails' select order: an explicit **None** first,
  # then the universe's events. Several Scenes may pick the same Event, so this
  # is a plain single-select rather than an exclusion list.
  def scene_event_choices(events)
    [ [ "None", "" ] ] + events.map { |event| [ event.display_string, event.id ] }
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
  # author typed it, so a validation error never silently clears the input.
  def scene_datetime_field_value(scene)
    return scene.datetime.strftime("%Y-%m-%dT%H:%M") if scene.datetime.present?

    raw = scene.read_attribute_before_type_cast(:datetime)
    raw.is_a?(String) ? raw : nil
  end

  # "Label: value" descriptions of the filters currently in effect, in the order
  # the search area lists them. The result set of a long story is otherwise
  # ambiguous, and an empty result has to be able to say what caused it.
  def scene_filter_summaries(filter, section_paths, scene_tag_paths)
    summaries = []
    summaries << "Search: “#{filter.text}”" if filter.text.present?
    if filter.ungrouped?
      summaries << "Section: #{SectionPaths::UNGROUPED_LABEL}"
    elsif filter.section_id
      summaries << "Section: #{section_paths.label_for(filter.section_id)}"
    end
    if filter.scene_tag
      summaries << "Scene tag: #{scene_tag_paths.label_for(filter.scene_tag)}"
    end
    summaries << "In-world from #{filter.from_date.iso8601}" if filter.from_date
    summaries << "In-world to #{filter.to_date.iso8601}" if filter.to_date
    summaries
  end
end
