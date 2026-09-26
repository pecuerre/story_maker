# Descriptors for the Scene Items tab. Every row is a stored presence link, so
# unlike the Characters tab there is only one source to label and nothing to
# reconcile.
module SceneItemsHelper
  # [ label, value ] pairs for the add picker, in the same name order the Items
  # workspace uses.
  def scene_item_choices(items)
    items.map { |item| [ item.name, item.id ] }
  end

  # The role as the row states it. A blank role is a real state, not a missing
  # value: the author recorded that the item appears without saying how.
  def scene_item_role_label(entry)
    entry.role.presence || "No role recorded"
  end

  # The values the modal needs to reopen an existing link. Both fields travel,
  # because both are editable in the modal.
  def scene_item_fields_json(link)
    { item_id: link.item_id, role: link.role }.to_json
  end
end
