require "test_helper"

class CharacterTagTest < ActiveSupport::TestCase
  test "requires a name" do
    character_tag = CharacterTag.new(universe: universes(:universe_one))

    assert_not character_tag.valid?
    assert_includes character_tag.errors[:name], "can't be blank"
  end

  test "rejects a parent from another universe" do
    character_tag = CharacterTag.new(universe: universes(:universe_one), name: "Child", parent: character_tags(:character_tag_three))

    assert_not character_tag.valid?
    assert_includes character_tag.errors[:parent], "must belong to the same universe"
  end

  test "rejects a descendant as parent" do
    root = CharacterTag.create!(universe: universes(:universe_one), name: "Root")
    child = CharacterTag.create!(universe: universes(:universe_one), name: "Child", parent: root)

    root.parent = child

    assert_not root.valid?
    assert_includes root.errors[:parent], "cannot be a descendant"
  end
end
