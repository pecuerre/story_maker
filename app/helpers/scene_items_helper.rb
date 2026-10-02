# Descriptors for the Scene Items tab. Every row is a stored presence link, so
# unlike the Characters tab there is only one source to label and nothing to
# reconcile.
#
# The role is the author's own free text and is returned unchanged, and the pairs
# this tab offers are a record's own name and id. Both answers have one home in
# `ScenesHelper`, which the Characters tab, the Locations tab, the Dialogue
# speaker picker, and the "Appears in Scenes" section share, so this tab and those
# cannot describe the same participation differently.
module SceneItemsHelper
  # [ label, value ] pairs for the add picker, in the same name order the Items
  # workspace uses. The names are record names and the values are record ids, so
  # neither is translated.
  def scene_item_choices(items)
    name_id_choices(items)
  end

  # The role as the row states it. A blank role is a real state, not a missing
  # value: the author recorded that the item appears without saying how.
  def scene_item_role_label(entry)
    scene_role_label(entry)
  end

  # The values the modal needs to reopen an existing link. Both fields travel,
  # because both are editable in the modal.
  def scene_item_fields_json(link)
    { item_id: link.item_id, role: link.role }.to_json
  end
end
