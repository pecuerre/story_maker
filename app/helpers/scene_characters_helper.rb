# Descriptors for the Scene Characters tab: the two participation sources are
# shown side by side and never merged into one stored row, so a Character who
# both participates explicitly and speaks is labelled as doing both.
#
# The role is the author's own free text and is returned unchanged, and the pairs
# this tab offers are a record's own name and id. Both answers have one home in
# `ScenesHelper`, which the Items tab, the Locations tab, the Dialogue speaker
# picker, and the "Appears in Scenes" section share, so this tab and those cannot
# describe the same participation differently.
module SceneCharactersHelper
  # [ label, value ] pairs for the add picker, in the same name order the
  # Characters workspace uses. The names are record names and the values are record
  # ids, so neither is translated.
  def scene_character_choices(characters)
    name_id_choices(characters)
  end

  # The role as the row states it. A blank role is a real state, not a missing
  # value: the author recorded participation without saying how.
  def scene_character_role_label(entry)
    scene_role_label(entry)
  end

  # The badges one participant row carries, so the difference between a stored
  # presence link and a derived speaker is always visible. The speaker badge's
  # count is resolved with a `count:`, so its plural comes from the locale.
  def scene_character_participation_badges(entry)
    badges = []
    badges << t("scenes.characters.participant_badge") if entry.explicitly_linked?
    badges << t("scenes.participation.speaks_in",
      count: count_with_label(entry.speaking_elements.size, "element")) if entry.speaks?
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
