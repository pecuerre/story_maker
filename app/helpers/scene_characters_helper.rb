# Descriptors for the Scene Characters tab: the two participation sources are
# shown side by side and never merged into one stored row, so a Character who
# both participates explicitly and speaks is labelled as doing both.
module SceneCharactersHelper
  # [ label, value ] pairs for the add picker, in the same name order the
  # Characters workspace uses.
  def scene_character_choices(characters)
    characters.map { |character| [ character.name, character.id ] }
  end

  # The role as the row states it. A blank role is a real state, not a missing
  # value: the author recorded participation without saying how.
  def scene_character_role_label(entry)
    entry.role.presence || "No role recorded"
  end

  # The badges one participant row carries, so the difference between a stored
  # presence link and a derived speaker is always visible.
  def scene_character_participation_badges(entry)
    badges = []
    badges << "Participant" if entry.explicitly_linked?
    badges << "Speaks in #{pluralize(entry.speaking_elements.size, 'element')}" if entry.speaks?
    badges
  end

  # Where a derived speaker's participation comes from. A stored link has no such
  # list, because the link itself is the fact.
  def scene_character_speaking_in(entry)
    return nil unless entry.speaks?

    entry.speaking_elements.map(&:name)
  end

  # The values the modal needs to reopen an existing link. Both fields travel,
  # because both are editable in the modal.
  def scene_character_fields_json(link)
    { character_id: link.character_id, role: link.role }.to_json
  end
end
