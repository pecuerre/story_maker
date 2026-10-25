require "test_helper"

class FactionTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
require "test_helper"

class FactionTest < ActiveSupport::TestCase
  test "requires a name and allows no faction tags" do
    faction = Faction.new(universe: universes(:universe_one))

    assert_not faction.valid?
    assert_includes faction.errors[:name], "can't be blank"
    assert Faction.create!(universe: universes(:universe_one), name: "Untagged group")
  end

  test "generates a slug and stores the profile fields" do
    faction = Faction.create!(
      universe: universes(:universe_one),
      name: "The Glass Council",
      mission: "Keep the peace",
      actual_aims: "Control the archive",
      structure: "A rotating council",
      internal_divisions: "Two members disagree",
      resources: "A hidden library",
      would_never: "Destroy the archive",
      would_absolutely: "Protect the collection"
    )

    assert_equal "the-glass-council", faction.slug
    assert_equal [ "Keep the peace", "Control the archive", "A rotating council",
      "Two members disagree", "A hidden library", "Destroy the archive", "Protect the collection" ],
      [ faction.mission, faction.actual_aims, faction.structure, faction.internal_divisions,
        faction.resources, faction.would_never, faction.would_absolutely ]
    assert_includes faction.search_document[:body], "Control the archive"
  end

  test "rejects a faction tag from another universe" do
    faction = Faction.new(universe: universes(:universe_one), name: "Mis-scoped",
      faction_tags: [ faction_tags(:faction_tag_two) ])

    assert_not faction.valid?
    assert_includes faction.errors[:faction_tags], "must belong to the same universe"
  end

  test "soft deletion retains faction tag assignments for restore" do
    faction = factions(:faction_one)
    tag_ids = faction.faction_tag_ids

    faction.soft_delete

    assert_nil Faction.find_by(id: faction.id)
    assert_equal tag_ids, Faction.with_deleted.find(faction.id).faction_tag_ids

    faction.restore
    assert_equal tag_ids, faction.reload.faction_tag_ids
  end
end
