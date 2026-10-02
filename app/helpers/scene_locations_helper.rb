# Descriptors for the Scene Locations tab. Every row is a stored presence link,
# so unlike the Characters tab there is only one source to label and nothing to
# reconcile. The one extra concern here is the hierarchy: a nested place is shown
# with its ancestor path so two places called "Room" are never ambiguous, which is
# why this tab builds its own pairs from `LocationPaths` instead of the flat
# `ScenesHelper#name_id_choices` the other pickers use.
#
# The role is the author's own free text and is returned unchanged, and the
# blank-role sentence has one home in `ScenesHelper`, which the Characters tab,
# the Items tab, the Dialogue speaker picker, and the "Appears in Scenes" section
# share.
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
    scene_role_label(entry)
  end

  # A linked place's full ancestor path, falling back to its own name when the
  # universe tree this page was built from does not contain it. The path is built
  # from the author's own place names, so it is data and is never translated.
  def scene_location_label(location, location_paths)
    location_paths.label_for(location) || location.name
  end

  # The values the modal needs to reopen an existing link. Both fields travel,
  # because both are editable in the modal.
  def scene_location_fields_json(link)
    { location_id: link.location_id, role: link.role }.to_json
  end
end
