require "test_helper"

class FactionTagTest < ActiveSupport::TestCase
  test "requires a name and enforces color formats" do
    tag = FactionTag.new(universe: universes(:universe_one), name: "", bgcolor: "red")

    assert_not tag.valid?
    assert_includes tag.errors[:name], "can't be blank"
    assert_includes tag.errors[:bgcolor], "must be a hex color like #d3d3d3"
  end

  test "builds a hierarchy inside its universe" do
    root = FactionTag.create!(universe: universes(:universe_one), name: "Organization")
    child = FactionTag.create!(universe: root.universe, name: "Secret society", parent: root)

    assert_equal "organization", root.slug
    assert_equal root, child.parent
    assert_equal [ child ], root.children
  end

  test "rejects factions from another universe on the inverse association" do
    tag = faction_tags(:faction_tag_one)
    tag.factions = [ factions(:faction_other_universe) ]

    assert_not tag.valid?
    assert_includes tag.errors[:factions], "must belong to the same universe"
  end
end
