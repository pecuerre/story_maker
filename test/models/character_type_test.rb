require "test_helper"

class CharacterTypeTest < ActiveSupport::TestCase
  test "requires a name" do
    character_type = CharacterType.new(universe: universes(:universe_one))

    assert_not character_type.valid?
    assert_includes character_type.errors[:name], "can't be blank"
  end

  test "rejects a parent from another universe" do
    character_type = CharacterType.new(universe: universes(:universe_one), name: "Child", parent: character_types(:character_type_three))

    assert_not character_type.valid?
    assert_includes character_type.errors[:parent], "must belong to the same universe"
  end

  test "rejects a descendant as parent" do
    root = CharacterType.create!(universe: universes(:universe_one), name: "Root")
    child = CharacterType.create!(universe: universes(:universe_one), name: "Child", parent: root)

    root.parent = child

    assert_not root.valid?
    assert_includes root.errors[:parent], "cannot be a descendant"
  end
end
