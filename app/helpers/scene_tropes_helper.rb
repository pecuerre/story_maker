# Descriptors for the Scene Tropes tab. A row is one catalogue assignment, so the
# row's own name, description, craft note, and source link all come from the
# code-owned `TropeCatalog` entry rather than from the stored row.
module SceneTropesHelper
  # [ label, value ] pairs for the editor's picker, in the catalogue's curated
  # order. The label is the reference's own name and the value is its stable slug,
  # so neither is translated.
  def scene_trope_choices(entries)
    entries.map { |entry| [ entry.name, entry.slug ] }
  end

  # The context note as the row states it. A blank note is a real state, not a
  # missing value: the author recorded the detection without explaining it.
  def scene_trope_context_label(assignment)
    assignment.context_note.presence || t("tropes.assignments.no_context")
  end

  # The values the modal needs to reopen an existing assignment. Both fields
  # travel, because both are editable in the modal.
  def scene_trope_fields_json(assignment)
    { trope_slug: assignment.trope_slug, context_note: assignment.context_note }.to_json
  end
end
