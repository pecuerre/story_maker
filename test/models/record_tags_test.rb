require "test_helper"

class RecordTagsTest < ActiveSupport::TestCase
  test "returns an empty hash for no records" do
    assert_equal({}, RecordTags.for([]))
  end

  test "maps each record to the tags it carries" do
    character_one = characters(:character_one)
    character_two = characters(:character_two)

    tags = RecordTags.for([ character_one, character_two ])

    assert_equal [ character_tags(:character_tag_one).id ], tags.fetch(character_one.id).map(&:id)
    assert_equal [ character_tags(:character_tag_two).id ], tags.fetch(character_two.id).map(&:id)
  end

  test "orders each record's tags by name" do
    character = characters(:character_one)
    zeta = CharacterTag.create!(universe: universes(:universe_one), name: "Zeta")
    alpha = CharacterTag.create!(universe: universes(:universe_one), name: "Alpha")
    character.character_tags << zeta
    character.character_tags << alpha

    tags = RecordTags.for([ character ]).fetch(character.id)

    assert_equal %w[ Alpha Character\ tag\ one Zeta ], tags.map(&:name)
  end

  test "reads the tags of a different record type through its own join table" do
    location = locations(:location_one)

    tags = RecordTags.for([ location ])

    assert_equal [ location_tags(:location_tag_one).id ], tags.fetch(location.id).map(&:id)
  end
end
