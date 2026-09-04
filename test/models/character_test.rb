require "test_helper"

class CharacterTest < ActiveSupport::TestCase
  test "requires a name" do
    character = Character.new(story: stories(:story_one), character_type: character_types(:character_type_one))

    assert_not character.valid?
    assert_includes character.errors[:name], "can't be blank"
  end
end
