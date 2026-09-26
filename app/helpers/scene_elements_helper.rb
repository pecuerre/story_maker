# Descriptors for the Scene Element modal and the ordered Element list on Scene
# Details. The Element flow is JSON plus Stimulus (ADR 0011), so the editor's
# field values travel as a small JSON payload rather than a re-rendered form.
module SceneElementsHelper
  KIND_LABELS = {
    SceneElement::NARRATION => "Narration",
    SceneElement::DIALOGUE => "Dialogue"
  }.freeze

  KIND_DESCRIPTIONS = {
    SceneElement::NARRATION => "Description or action, with no one speaking.",
    SceneElement::DIALOGUE => "A spoken block. Name everyone who speaks in it."
  }.freeze

  def scene_element_kind_label(element)
    KIND_LABELS.fetch(element.kind, element.kind)
  end

  def scene_element_kind_options
    SceneElement::KINDS.map { |kind| [ KIND_LABELS.fetch(kind), kind ] }
  end

  # [ label, value ] pairs for the many-speaker picker. Every universe Character
  # is offered, because the same Character may speak in any number of Elements.
  def scene_element_speaker_choices(characters)
    characters.map { |character| [ character.name, character.id ] }
  end

  # A short, single-line preview of the Element content. The full prose stays on
  # the list row itself; this is what the Scenes list shows for a scene that has
  # Elements.
  def scene_element_preview(element, length: 140)
    body = element.body.to_s.squish
    return nil if body.blank?

    body.truncate(length, separator: " ")
  end

  # One sentence describing what a Dialogue's speaker links do and do not mean.
  # It is repeated in the editor because "who speaks here" is the question an
  # author asks first, and "which line is theirs" is the one this version cannot
  # answer.
  def scene_element_speaker_note(element)
    return nil unless element.dialogue?

    names = element.characters.map(&:name).sort

    if names.empty?
      "A dialogue must name at least one speaker."
    else
      "#{names.to_sentence} #{names.one? ? 'speaks' : 'speak'} in this block. " \
        "The link records who is in the conversation, not which line belongs to whom."
    end
  end

  # The values the modal needs to reopen an existing Element.
  def scene_element_fields_json(element)
    {
      kind: element.kind,
      name: element.name,
      body: element.body,
      character_ids: element.character_ids
    }.to_json
  end
end
