# One Story's cast as a count: how many of its live Scenes each Character
# appears in.
#
# This is the Story-overview chart's read, and it is deliberately the same
# presence union every other appearance surface reports: `SceneParticipants`
# merges an explicit `SceneCharacter` link and a Dialogue speaker, so a Character
# who both participates and speaks in one Scene is counted once. An Event
# reference is a source for an Event's appearances, not for a Character's, and a
# prose mention is a suggestion rather than an appearance; neither adds a
# Character here.
#
# The measure is Story-scoped: only this Story's live Scenes count, and a
# Character with no recorded presence in any of them is left out rather than
# printed as a zero. The reads are grouped, so a Story of hundreds of Scenes
# costs the same number of queries as a short one.
class CharacterSceneCounts
  Entry = Struct.new(:character, :scene_count, keyword_init: true)

  attr_reader :story

  def self.for(story)
    new(story)
  end

  def initialize(story)
    @story = story
  end

  # Characters with at least one recorded appearance, most appearances first and
  # then by name. The name tie-break is the same one the Appearance grid uses.
  def entries
    @entries ||= build_entries
  end

  def any?
    entries.any?
  end

  def scenes?
    scene_count.positive?
  end

  # The denominator every bar is measured against: the whole Story's live Scene
  # count, including Scenes in which nobody appears.
  def scene_count
    @scene_count ||= story.scenes.count
  end

  # The percentage of the Story's Scenes this Character appears in. Zero when the
  # Story has no Scenes, which is an empty chart rather than a division.
  def share_for(entry)
    return 0 if scene_count.zero?

    entry.scene_count * 100.0 / scene_count
  end

  private
    def build_entries
      scenes = story.scenes.to_a
      @scene_count = scenes.size

      appearances = Hash.new(0)
      SceneParticipants.character_ids_by_scene(scenes).each_value do |character_ids|
        character_ids.each { |character_id| appearances[character_id] += 1 }
      end
      return [] if appearances.empty?

      # Scoped through the Story's Universe, so a Character from another Universe
      # can never reach a row even if a corrupt link named it, and the default
      # scope keeps a soft-deleted Character out.
      characters = story.universe.characters.where(id: appearances.keys).index_by(&:id)

      appearances.filter_map do |character_id, scene_count|
        character = characters[character_id]
        next if character.nil?

        Entry.new(character: character, scene_count: scene_count)
      end.sort_by { |entry| [ -entry.scene_count, entry.character.name.to_s, entry.character.id ] }
    end
end
