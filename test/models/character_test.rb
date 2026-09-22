require "test_helper"

class CharacterTest < ActiveSupport::TestCase
  test "requires a name" do
    character = Character.new(universe: universes(:universe_one), character_tags: [ character_tags(:character_tag_one) ])

    assert_not character.valid?
    assert_includes character.errors[:name], "can't be blank"
  end
end
