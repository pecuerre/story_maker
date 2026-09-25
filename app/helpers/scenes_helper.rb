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

  # What the datetime-local field must render. A rejected value is kept as the
  # author typed it, so a validation error never silently clears the input.
  def scene_datetime_field_value(scene)
    return scene.datetime.strftime("%Y-%m-%dT%H:%M") if scene.datetime.present?

    raw = scene.read_attribute_before_type_cast(:datetime)
    raw.is_a?(String) ? raw : nil
  end
end
