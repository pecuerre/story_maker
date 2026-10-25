# Who is at one Location, read from Scene presence in the current Story.
#
# This is the forward direction of a Scene's Locations tab: the Locations tab
# says "this Scene happens here", and this object answers "who is here when it
# does". It is a read model, never a stored record — the same place holds
# different people at different moments, so a presence answer that belonged to
# the Location itself would be wrong for every Scene but one.
#
# **Every individual is a Scene participant, by the union rule.** The persons on
# a row are exactly `SceneParticipants`' union of an explicit `SceneCharacter`
# link and a derived Dialogue speaker, one person per row, never a sum. A
# Character's free-text link `role` is their stated reason for being here; a
# speaker with no link has no stored role and says so.
#
# **A faction is present because one of its members is present.** There is no
# Scene-Faction link (see ADR 0033): the factions on a row are the union of the
# participants' Faction memberships, so a faction can never appear without a
# named individual who represents it.
#
# **Nothing falls back to another Story.** A Scene belongs to exactly one Story,
# and a Location is shared by every Story in the Universe, so without a current
# Story there is nothing to report rather than another Story's scenes.
#
# The query count is fixed per page: every linked Scene, its participants, and
# their factions are read in a handful of grouped queries, so a Location used in
# one Scene costs the same as one used in all of them.
class LocationPresence
  # One Scene that happens at the Location, with the people and factions its
  # presence links record. `location_role` is the author's note on how the Scene
  # uses the place, not a reason for anyone being there.
  Entry = Struct.new(:scene, :location_role, :participants, :factions, keyword_init: true)

  # One Character at the Location. `linked` is separate from `role` because a
  # presence link with no role still records a person, and `speaks` records the
  # second, derived participation source.
  Participant = Struct.new(:character, :role, :linked, :speaks, keyword_init: true) do
    def linked?
      linked
    end

    def speaks?
      speaks
    end
  end

  attr_reader :location, :story

  def initialize(location, story)
    @location = location
    @story = story
  end

  def self.for(location, story:)
    new(location, story)
  end

  # One entry per Scene that happens here, in narrative order.
  def entries
    return [] if location.nil? || story.nil?

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
      links = location.scene_locations
        .joins(:scene)
        .where(scenes: { story_id: story.id })
        .reorder("scenes.position", "scenes.id")
        .includes(:scene)
        .to_a
      return [] if links.empty?

      participants_by_scene = participants_grouped_by_scene(links)
      factions_by_character = factions_grouped_by_character(participants_by_scene)

      links.map do |link|
        participants = participants_by_scene[link.scene_id] || []
        factions = participants
          .flat_map { |participant| factions_by_character[participant.character.id] || [] }
          .uniq(&:id)
          .sort_by { |faction| [ faction.name.to_s.downcase, faction.id ] }

        Entry.new(scene: link.scene, location_role: link.role,
          participants: participants, factions: factions)
      end
    end

    # The union of stored links and derived speakers, grouped by Scene and
    # ordered by Character name. One Character who both participates and speaks
    # is one Participant carrying both facts.
    def participants_grouped_by_scene(links)
      scene_ids = links.map(&:scene_id)
      speaking_pairs = SceneParticipants.speaking_pairs(links.map(&:scene))
      speaking_keys = speaking_pairs.map { |character_id, scene_id| [ scene_id, character_id ] }.to_set
      stored_links = SceneCharacter.where(scene_id: scene_ids).to_a
      links_by_key = stored_links.index_by { |link| [ link.scene_id, link.character_id ] }
      characters = Character
        .where(id: stored_links.map(&:character_id) | speaking_pairs.map(&:first))
        .index_by(&:id)

      # Every (Scene, Character) pair either source contributes, so a Character
      # present through only one source still gets the Participant the other
      # source would have created.
      (links_by_key.keys | speaking_keys.to_a)
        .group_by(&:first)
        .transform_values do |pairs|
          pairs.filter_map { |scene_id, character_id|
            character = characters[character_id]
            next if character.nil?

            link = links_by_key[[ scene_id, character_id ]]
            Participant.new(character: character, role: link&.role, linked: link.present?,
              speaks: speaking_keys.include?([ scene_id, character_id ]))
          }.sort_by { |participant| [ participant.character.name.to_s.downcase, participant.character.id ] }
        end
    end

    # character_id => [Faction] for the participants, in one query through the
    # join table. The scoped HABTM association cannot be joined or eager-loaded,
    # so the join is written out; the Universe filter keeps a corrupt cross-scope
    # membership from rendering.
    def factions_grouped_by_character(participants_by_scene)
      character_ids = participants_by_scene.values.flatten.map { |participant| participant.character.id }.uniq
      return {} if character_ids.empty?

      Faction.where(universe_id: location.universe_id)
        .joins("INNER JOIN characters_factions ON characters_factions.faction_id = factions.id")
        .where(characters_factions: { character_id: character_ids })
        .select("factions.*", "characters_factions.character_id AS membership_character_id")
        .order("factions.name", "factions.id")
        .group_by { |faction| faction[:membership_character_id] }
    end
end
