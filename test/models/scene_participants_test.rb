require "test_helper"

# Participation in a Scene is read from two independent sources and is never
# their sum: a Character who both participates explicitly and speaks in a
# Dialogue is one participant.
class SceneParticipantsTest < ActiveSupport::TestCase
  setup do
    @scene = scenes(:scene_one)
    @alt_scene = scenes(:scene_alt)
  end

  test "an explicit link and a derived speaker are one participant, not two" do
    participants = SceneParticipants.for(@scene)

    # `character_one` is explicitly linked with a role and also speaks in
    # `dialogue_one`; `character_two` is linked without a role and also speaks.
    assert_equal 2, participants.count
    assert_predicate participants, :any?
  end

  test "each entry keeps the two sources distinguishable" do
    entry = SceneParticipants.for(@scene).entries.find { |item| item.character == characters(:character_one) }

    assert_predicate entry, :explicitly_linked?
    assert_predicate entry, :speaks?
    assert_equal "setting", entry.role
    assert_equal [ "Michael teaches the waltz" ], entry.speaking_elements.map(&:name)
  end

  test "a character who only speaks is a participant without a stored link" do
    scene = @scene.story.scenes.create!(name: "Solo stage")
    element = scene.scene_elements.create!(name: "Alone", kind: "dialogue",
      characters: [ characters(:character_one) ])

    entry = SceneParticipants.for(scene).entries.sole
    assert_equal characters(:character_one), entry.character
    assert_not entry.explicitly_linked?
    assert_predicate entry, :speaks?
    assert_equal [ element ], entry.speaking_elements
  end

  test "a character with neither source is not a participant" do
    offstage = @scene.universe.characters.create!(name: "Off stage")

    assert_not_includes SceneParticipants.for(@scene).entries.map(&:character), offstage
  end

  test "a scene with no participation has no entries" do
    participants = SceneParticipants.for(scenes(:scene_three))

    assert_empty participants.entries
    assert_equal 0, participants.count
    assert_not participants.any?
  end

  test "counts per scene come from one union, not from added sources" do
    counts = SceneParticipants.counts_by_scene([ @scene, @alt_scene ])

    assert_equal 2, counts[@scene.id]
    # `dialogue_alt` names `character_one` with no presence link at all.
    assert_equal 1, counts[@alt_scene.id]
    # A Scene nobody takes part in is absent rather than mapped to zero, so a
    # caller cannot confuse "no row" with a real measurement.
    assert_nil counts[scenes(:scene_three).id]
  end

  test "no scenes means no counts and no queries" do
    assert_equal({}, SceneParticipants.counts_by_scene([]))
    assert_equal({}, SceneParticipants.character_ids_by_scene([]))
  end

  test "the character ids behind a count are deduplicated across both sources" do
    ids = SceneParticipants.character_ids_by_scene([ @scene ])[@scene.id]

    assert_equal ids.uniq, ids
    assert_equal [ characters(:character_one).id, characters(:character_two).id ].sort, ids.sort
  end

  test "only explicit links are offered to the add, remove, and role controls" do
    derived_only = @scene.story.scenes.create!(name: "Derived only")
    derived_only.scene_elements.create!(name: "Two voices", kind: "dialogue",
      characters: [ characters(:character_one) ])

    assert_equal @scene.scene_characters.order(:id).to_a,
      SceneParticipants.for(@scene).explicit_links.sort_by(&:id)
    assert_empty SceneParticipants.for(derived_only).explicit_links
    assert_equal 1, SceneParticipants.for(derived_only).count
  end
end
