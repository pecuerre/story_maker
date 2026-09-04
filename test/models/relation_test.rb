require "test_helper"

class RelationTest < ActiveSupport::TestCase
  setup do
    @story = stories(:story_one)
    @character = characters(:character_one)
    @relation_type = RelationType.new(story: @story, name: "Child of")
  end

  test "requires both characters and a relation type" do
    relation = Relation.new(story: @story)

    assert_not relation.valid?
    assert_includes relation.errors[:character1], "can't be blank"
    assert_includes relation.errors[:character2], "can't be blank"
    assert_includes relation.errors[:relation_type], "can't be blank"
  end

  test "allows repeated relations between the same characters" do
    @relation_type.save!
    attributes = { story: @story, character1: @character, character2: characters(:character_two), relation_type: @relation_type }

    assert Relation.create!(attributes)
    assert Relation.create!(attributes)
  end
end
