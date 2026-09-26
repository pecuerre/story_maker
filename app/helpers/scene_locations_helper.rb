# Descriptors for the Scene Locations tab. Every row is a stored presence link,
# so unlike the Characters tab there is only one source to label and nothing to
# reconcile. The one extra concern here is the hierarchy: a nested place is shown
# with its ancestor path so two places called "Room" are never ambiguous.
module SceneLocationsHelper
  # [ label, value ] pairs for the add picker, depth-indented and in root-first
  # order so a child can never be offered before its parent.
  def scene_location_choices(location_paths)
    location_paths.choices
  end

  # The role as the row states it. A blank role is a real state, not a missing
  # value: the author recorded that the place is part of the scene without saying
  # how.
  def scene_location_role_label(entry)
    entry.role.presence || "No role recorded"
  end

  # A linked place's full ancestor path, falling back to its own name when the
  # universe tree this page was built from does not contain it.
  def scene_location_label(location, location_paths)
    location_paths.label_for(location) || location.name
  end

  # The values the modal needs to reopen an existing link. Both fields travel,
  # because both are editable in the modal.
  def scene_location_fields_json(link)
    { location_id: link.location_id, role: link.role }.to_json
  end
end
