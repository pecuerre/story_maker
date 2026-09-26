# Who takes part in a Scene, read from the two independent sources the domain
# model allows.
#
# An explicit `SceneCharacter` presence link may carry a role, and a Dialogue
# Element may name Characters who speak. Speaking is never stored as a presence
# link, so the same Character can be both, and a Character who only speaks is
# still a participant. Every count and list derived here is therefore the
# *union* of the two sources, never their sum: a Character who participates and
# speaks is one participant, not two.
#
# The two queries it runs for many Scenes and the few it runs for one Scene are
# the same shape, so a list of Scenes costs a fixed number of queries rather
# than one per row.
class SceneParticipants
  # One Character in one Scene, with each source kept distinguishable.
  Entry = Struct.new(:character, :link, :speaking_elements, keyword_init: true) do
    def role
      link&.role
    end

    # Stored participation, as opposed to participation derived from a Dialogue.
    def explicitly_linked?
      link.present?
    end

    def speaks?
      speaking_elements.any?
    end
  end

  attr_reader :scene

  def initialize(scene)
    @scene = scene
  end

  def self.for(scene)
    new(scene)
  end

  # Participants per Scene, for a list that shows a count on every row. Scenes
  # without a participant are absent from the hash rather than mapped to zero, so
  # a caller can use `dig`/`[]` without a default of its own.
  def self.counts_by_scene(scenes)
    character_ids_by_scene(scenes).transform_values(&:size)
  end

  def self.character_ids_by_scene(scenes)
    scene_ids = scenes.map(&:id)
    return {} if scene_ids.empty?

    grouped = Hash.new { |hash, key| hash[key] = [] }

    SceneCharacter.where(scene_id: scene_ids).pluck(:scene_id, :character_id).each do |scene_id, character_id|
      grouped[scene_id] << character_id
    end

    # Derived speakers come through the Character side of the speaker link, so
    # one query answers "who speaks anywhere in these Scenes". The scene column
    # is named in full because `Character` has no `scene_id` of its own.
    Character.joins(:scene_elements)
      .where(scene_elements: { scene_id: scene_ids })
      .distinct
      .pluck(:id, "scene_elements.scene_id")
      .each { |character_id, scene_id| grouped[scene_id] << character_id }

    grouped.transform_values(&:uniq)
  end

  # The participants of one Scene, ordered by Character name. Explicit links and
  # derived speakers are merged in memory after both have been preloaded, so a
  # row can show the role and the speaking Elements at the same time.
  def entries
    @entries ||= begin
      links = scene.scene_characters.includes(:character).to_a
      links_by_character = links.index_by(&:character_id)

      elements = scene.scene_elements.includes(:characters).reorder(:position, :id).to_a
      speaking_elements = Hash.new { |hash, key| hash[key] = [] }
      elements.each do |element|
        element.characters.each { |character| speaking_elements[character.id] << element }
      end

      # Both sources have their Characters preloaded, so the merge costs no
      # further query.
      characters = (links.map(&:character) + elements.flat_map(&:characters))
        .uniq(&:id)
        .sort_by { |character| [ character.name.to_s.downcase, character.id ] }

      characters.map do |character|
        Entry.new(character: character, link: links_by_character[character.id],
          speaking_elements: speaking_elements[character.id])
      end
    end
  end

  def count
    entries.size
  end

  def any?
    entries.any?
  end

  # Only the Characters the author linked explicitly, which is what the
  # add/remove/role controls act on. A derived speaker has no link of its own.
  def explicit_links
    entries.select(&:explicitly_linked?).map(&:link)
  end
end
