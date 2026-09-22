require "test_helper"

class RelationTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @character = characters(:character_one)
    @relation_tag = RelationTag.new(universe: @universe, name: "Child of")
  end

  test "requires both characters and a relation tag" do
    relation = Relation.new(universe: @universe)

    assert_not relation.valid?
    assert_includes relation.errors[:character1], "can't be blank"
    assert_includes relation.errors[:character2], "can't be blank"
    assert_includes relation.errors[:relation_tags], "can't be blank"
  end

  test "allows repeated relations between the same characters" do
    @relation_tag.save!
    attributes = { universe: @universe, character1: @character, character2: characters(:character_two), relation_tags: [ @relation_tag ] }

    assert Relation.create!(attributes)
    assert Relation.create!(attributes)
  end
end
