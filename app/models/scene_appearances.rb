# The Scenes of one Story in which a shared universe record appears, and why.
#
# This is the reverse direction of the Scene workspace tabs. A record can be
# present in a Scene for different reasons, and the reasons are never merged into
# one stored row:
#
# - a **stored presence link** (`SceneCharacter`, `SceneItem`, `SceneLocation`),
#   which may carry the author's own free-text role;
# - a **Dialogue speaker**, which is derived from the Element and never becomes a
#   presence link, so the same Character can be both and is still one appearance;
# - an **Event reference**, where the Scene's optional `event` is this Event.
#
# Two boundaries are deliberate. A Scene is never deduplicated against the Event
# it depicts, so several Scenes appear here for one Event while `position` stays
# the narrative order. And nothing falls back to the Universe's first Story: a
# Story is only ever the one the request actually selected, so a record with no
# current Story has no appearances rather than a wrong Story's.
#
# The query count is fixed per record type, so a details page costs the same
# whether the record appears in one Scene or in all of them.
class SceneAppearances
  # One Scene in which the record appears, with each source kept distinguishable.
  # `linked` is separate from `role` because a presence link with no role is still
  # an appearance: the author recorded the fact and chose not to annotate it.
  Entry = Struct.new(:scene, :linked, :role, :speaking_elements, :event_reference, keyword_init: true) do
    # Stored participation, as opposed to participation derived from a Dialogue.
    def linked?
      linked
    end

    def speaks?
      speaking_elements.any?
    end

    # The Scene points at this record as its optional shared in-world Event, so
    # the Scene depicts it rather than merely using it.
    def depicted?
      event_reference
    end
  end

  # The presence-link association each world record declares on its own side. A
  # record without one here is reached through a different source, which is why
  # this list is the dispatch rather than a case statement.
  PRESENCE_ASSOCIATIONS = {
    "Character" => :scene_characters,
    "Item" => :scene_items,
    "Location" => :scene_locations
  }.freeze

  attr_reader :record, :story

  def initialize(record, story)
    @record = record
    @story = story
  end

  def self.for(record, story:)
    new(record, story)
  end

  # Appearances in narrative order, which is Scene `position` and never the
  # in-world chronology of a datetime or an Event's timeline.
  def entries
    return [] if record.nil? || story.nil?

    @entries ||= build_entries
  end

  def count
    entries.size
  end

  def any?
    entries.any?
  end

  private
    def build_entries
      roles_by_scene = presence_roles
      speaking_by_scene = speaker_element_names
      depicted = event_referenced_scene_ids

      scene_ids = (roles_by_scene.keys + speaking_by_scene.keys + depicted.to_a).uniq
      return [] if scene_ids.empty?

      # One ordered query for the Scene rows themselves. The order comes from the
      # database rather than from the collected ids, so the section reads as
      # narrative order no matter which source surfaced a Scene first.
      scenes = Scene.where(id: scene_ids).reorder(:position, :id).index_by(&:id)

      scenes.filter_map do |scene_id, scene|
        linked = roles_by_scene.key?(scene_id)
        speaking = speaking_by_scene[scene_id] || []
        is_depicted = depicted.include?(scene_id)
        next unless linked || speaking.any? || is_depicted

        Entry.new(scene: scene, linked: linked, role: roles_by_scene[scene_id],
          speaking_elements: speaking, event_reference: is_depicted)
      end
    end

    # scene_id => free-text role, where the role itself may be nil. A presence
    # link with no role still has its scene_id as a key, which is what makes it an
    # appearance rather than an absence.
    def presence_roles
      association = PRESENCE_ASSOCIATIONS[record.class.name]
      return {} if association.nil?

      record.public_send(association)
        .joins(:scene)
        .where(scenes: { story_id: story.id })
        .pluck(:scene_id, :role)
        .to_h
    end

    # Only a Dialogue names speakers, so this is empty for every other record and
    # is skipped rather than queried.
    def speaker_element_names
      return {} unless record.is_a?(Character)

      SceneElement.joins(:characters, :scene)
        .where(characters: { id: record.id }, scenes: { story_id: story.id })
        .reorder("scene_elements.position", "scene_elements.id")
        .pluck("scenes.id", "scene_elements.name")
        .group_by(&:first)
        .transform_values { |rows| rows.map(&:last) }
    end

    # An Event is not a presence link: a Scene points at it as an optional shared
    # fact, and several Scenes may point at the same one.
    def event_referenced_scene_ids
      return Set.new unless record.is_a?(Event)

      Scene.where(event_id: record.id, story_id: story.id).pluck(:id).to_set
    end
end
