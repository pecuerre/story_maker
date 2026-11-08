# Descriptors for the Scene Element modal and the ordered Element list on Scene
# Details. The Element flow is JSON plus Stimulus (ADR 0011), so the editor's
# field values travel as a small JSON payload rather than a re-rendered form.
#
# The kind *labels* and the kind *descriptions* are chrome, so they are resolved
# per request through `scenes.elements.kinds.*` rather than held here as English
# strings: `KIND_LABEL_KEYS` and `KIND_DESCRIPTION_KEYS` are frozen constants, and
# a constant that resolved `t()` would be translated once, in whatever locale
# happened to load this module first, and every later request would render that
# one language — the same rule `ModalFields` and `TagsHelper` follow.
#
# What stays a value is the `kind` itself: `narration` and `dialogue` are what
# the select stores and what the browser matches on, so they are never
# translated. Only the label beside a kind is a key.
module SceneElementsHelper
  KIND_LABEL_KEYS = {
    SceneElement::NARRATION => "scenes.elements.kinds.narration",
    SceneElement::DIALOGUE => "scenes.elements.kinds.dialogue"
  }.freeze

  KIND_DESCRIPTION_KEYS = {
    SceneElement::NARRATION => "scenes.elements.kinds.narration_description",
    SceneElement::DIALOGUE => "scenes.elements.kinds.dialogue_description"
  }.freeze

  # An unknown kind falls back to the stored value rather than to a missing
  # translation: a value this version does not know is not copy it can invent.
  def scene_element_kind_label(element)
    key = KIND_LABEL_KEYS[element.kind]

    key ? t(key) : element.kind
  end

  def scene_element_kind_options
    SceneElement::KINDS.map { |kind| [ scene_element_kind_description_label(kind), kind ] }
  end

  # The one-line explanation the type selector shows under itself. The browser
  # prints the same prose from the serialized hash below, so both come from one
  # key.
  def scene_element_kind_description(kind)
    key = KIND_DESCRIPTION_KEYS[kind]

    key ? t(key) : ""
  end

  def scene_element_kind_description_label(kind)
    key = KIND_LABEL_KEYS[kind]

    key ? t(key) : kind
  end

  # The descriptions keyed by the `kind` **value**, because this is what the
  # browser matches on: it reads `descriptions[select.value]` and the select
  # holds `narration`/`dialogue`. The keys are therefore data and the prose is
  # the chrome, which is the opposite of a translated key.
  def scene_element_kind_descriptions
    SceneElement::KINDS.to_h { |kind| [ kind, scene_element_kind_description(kind) ] }
  end

  # [ label, value ] pairs for a dialogue turn's speaker picker. Every universe
  # Character is offered, because the same Character may speak in any number of
  # Elements, and the final pair is the non-Character choice: the line then
  # carries the speaker tag instead of naming a record. The Character pairs are
  # `ScenesHelper#name_id_choices`, shared with the three participation tabs, so a
  # Character offered here is offered under the same name and with the same value
  # there.
  def scene_element_speaker_choices(characters)
    name_id_choices(characters) + [
      [ t("scenes.elements.dialogue_turns.non_character_speaker"), SceneDialogueTurn::NON_CHARACTER_SPEAKER ]
    ]
  end

  # A turn's speaker is a Character record or the non-Character label. The label
  # is chrome, so it is resolved here rather than stored on the turn.
  def scene_dialogue_turn_speaker_name(turn)
    turn.speaker&.name || t("scenes.elements.dialogue_turns.non_character_speaker")
  end

  # A short, single-line preview of the Element content. The full prose stays on
  # the list row itself; this is what the Scenes list shows for a scene that has
  # Elements.
  def scene_element_preview(element, length: 140)
    body = element.body.to_s.squish
    return nil if body.blank?

    body.truncate(length, separator: " ")
  end

  # The measure beside an Element's kind badge: a Narration reports its stored
  # word count and a Dialogue reports how many spoken lines it holds. Both are
  # read from records the page already loaded, so the row costs no extra query.
  def scene_element_length_label(element)
    if element.narration?
      t("scenes.elements.word_count", count: element.word_count)
    elsif element.dialogue?
      t("scenes.elements.line_count", count: element.scene_dialogue_turns.size)
    end
  end

  # The values the modal needs to reopen an existing Element. A Dialogue's turns
  # travel with it so the editor can show the ordered turn list in the same modal.
  def scene_element_fields_json(element)
    {
      kind: element.kind,
      name: element.name,
      body: element.body,
      turns: element.scene_dialogue_turns.reorder(:position, :id).map do |turn|
        scene_dialogue_turn_fields(turn)
      end,
      turns_create_url: universe_story_scene_scene_element_scene_dialogue_turns_path(
        universe_slug: element.story.universe.to_param,
        story_id: element.story,
        scene_id: element.scene,
        scene_element_id: element
      )
    }.to_json
  end

  # The browser editor needs the same scoped mutation URLs for a turn that the
  # server uses to resolve it. Keeping them beside the serialized fields avoids
  # constructing nested routes from ids in JavaScript.
  def scene_dialogue_turn_fields(turn)
    route_keys = {
      universe_slug: turn.universe.to_param,
      story_id: turn.story,
      scene_id: turn.scene,
      scene_element_id: turn.scene_element,
      id: turn
    }

    {
      id: turn.id,
      speaker_id: turn.speaker_id,
      speaker_value: turn.speaker_id || SceneDialogueTurn::NON_CHARACTER_SPEAKER,
      speaker_name: scene_dialogue_turn_speaker_name(turn),
      body: turn.body,
      parenthetical: turn.parenthetical,
      position: turn.position,
      update_url: universe_story_scene_scene_element_scene_dialogue_turn_path(**route_keys),
      move_up_url: move_universe_story_scene_scene_element_scene_dialogue_turn_path(**route_keys, direction: "up"),
      move_down_url: move_universe_story_scene_scene_element_scene_dialogue_turn_path(**route_keys, direction: "down"),
      destroy_url: universe_story_scene_scene_element_scene_dialogue_turn_path(**route_keys)
    }
  end
end
