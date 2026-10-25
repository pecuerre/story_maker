require "test_helper"

# `LocationPresence` answers "who is at this place" from Scene presence, so it
# must report the same union the Scene Characters tab does, keep each Scene as
# its own moment, and never borrow another Story's scenes.
class LocationPresenceTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @location = locations(:location_one)
    @story = stories(:story_one)
  end

  def presence_for(location = @location, story: @story)
    LocationPresence.for(location, story: story)
  end

  test "one entry per linked scene, in narrative order, with the location's own role" do
    entries = presence_for.entries

    assert_equal [ "Scene one", "Scene three" ], entries.map { |entry| entry.scene.name }
    assert_equal [ "setting", "arrives at" ], entries.map(&:location_role)
    assert_equal 2, presence_for.count
  end

  test "participants are the union of stored links and derived speakers" do
    entry = presence_for.entries.first

    # Alphabetical by Character name. character_one is linked and also speaks;
    # character_two is linked with no role and speaks; character_three only
    # speaks, through a Dialogue turn, and has no stored link.
    assert_equal [ "Character one", "Character three", "Character two" ],
      entry.participants.map { |participant| participant.character.name }

    one = entry.participants.first
    assert_predicate one, :linked?
    assert_predicate one, :speaks?
    assert_equal "setting", one.role

    two = entry.participants.last
    assert_predicate two, :linked?
    assert_nil two.role

    three = entry.participants.second
    assert_not_predicate three, :linked?
    assert_predicate three, :speaks?
    assert_nil three.role

    # Each Character is one participant, never one per source.
    assert_equal entry.participants.map(&:character).uniq.length, entry.participants.length
  end

  test "factions present are the memberships of the participants, once each" do
    entry = presence_for.entries.first

    # Only character_one belongs to a faction, so the faction is present because
    # its member is, and it appears once even though the Character is both linked
    # and speaking.
    assert_equal [ factions(:faction_one) ], entry.factions
  end

  test "a scene at the location with no participants is still a row, with both lists empty" do
    empty_hall = Location.create!(universe: @universe, name: "Empty hall")
    scenes(:scene_three).scene_locations.create!(location: empty_hall)

    entry = presence_for(empty_hall).entries.sole

    assert_equal "Scene three", entry.scene.name
    assert_empty entry.participants
    assert_empty entry.factions
  end

  test "a scene with several locations shows the same participants at each of them" do
    # `scene_one` links both `location_one` and `location_two`. A SceneCharacter
    # names the Scene, not one of its places, so the model cannot attribute a
    # person to a single Location inside a multi-place Scene; each place reports
    # the Scene's participants. The boundary is documented in
    # `docs/features/locations.md`.
    one = presence_for(locations(:location_one)).entries.first
    two = presence_for(locations(:location_two)).entries.sole

    assert_equal one.scene, two.scene
    assert_equal one.participants.map(&:character), two.participants.map(&:character)
    assert_equal one.factions, two.factions
  end

  test "a later scene in the same story is another moment at the same place" do
    later = @story.scenes.create!(name: "Same story, later", position: 9)
    later.scene_locations.create!(location: @location, role: "returned to")
    later.scene_characters.create!(character: characters(:character_two), role: "waiting")

    entry = presence_for.entries.last

    assert_equal "Same story, later", entry.scene.name
    assert_equal "returned to", entry.location_role
    assert_equal [ "Character two" ], entry.participants.map { |participant| participant.character.name }
    assert_equal "waiting", entry.participants.first.role
  end

  test "another story's scenes are not this location's presence" do
    # `scene_alt` belongs to the same Universe but to another Story, and the
    # shared Location can legitimately be linked there too. Without a current
    # Story there is nothing to report rather than a fallback.
    scenes(:scene_alt).scene_locations.create!(location: @location)
    assert_empty presence_for(story: nil).entries
    assert_not presence_for(story: nil).any?
    assert_not_includes presence_for.entries.map { |entry| entry.scene.name }, "Alt scene"
  end

  test "the query count does not follow the number of linked scenes" do
    shallow = count_queries { presence_for.entries }

    # A scene and a participant each, so the deeper case would expose a per-scene
    # query for links, Characters, or factions.
    3.times do |index|
      scene = @story.scenes.create!(name: "Crowded #{index}", position: 10 + index)
      scene.scene_locations.create!(location: @location)
      scene.scene_characters.create!(character: characters(:character_two))
    end

    deep = count_queries { presence_for.entries }

    assert_equal shallow, deep
    assert_equal 5, presence_for.count
  end
end
