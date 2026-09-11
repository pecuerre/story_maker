require "test_helper"

class OwnershipTest < ActiveSupport::TestCase
  setup do
    @story = stories(:story_one)
    @ownership_type = OwnershipType.create!(story: @story, name: "Owns")
  end

  test "requires an item, character, and ownership type" do
    ownership = Ownership.new(story: @story)

    assert_not ownership.valid?
    assert_includes ownership.errors[:item], "can't be blank"
    assert_includes ownership.errors[:character], "can't be blank"
    assert_includes ownership.errors[:ownership_types], "can't be blank"
  end

  test "rejects associated records from another story" do
    ownership = Ownership.new(
      story: @story,
      item: items(:item_one),
      character: characters(:character_one),
      ownership_types: [ OwnershipType.create!(story: stories(:story_two), name: "Owns") ]
    )

    assert_not ownership.valid?
    assert_includes ownership.errors[:ownership_types], "must belong to the ownership's story"
  end

  test "allows repeated ownerships" do
    attributes = {
      story: @story,
      item: items(:item_one),
      character: characters(:character_one),
      ownership_types: [ @ownership_type ]
    }

    assert Ownership.create!(attributes)
    assert Ownership.create!(attributes)
  end
end
