require "test_helper"

class LocationTest < ActiveSupport::TestCase
  test "requires a name" do
    location = Location.new(universe: universes(:universe_one))

    assert_not location.valid?
    assert_includes location.errors[:name], "can't be blank"
  end

  test "allows a location without tags" do
    assert Location.create!(universe: universes(:universe_one), name: "Untagged")
  end

  test "rejects a parent from another universe" do
    location = Location.new(universe: universes(:universe_one), name: "Child", location_tags: [ location_tags(:location_tag_one) ], parent: locations(:location_three))

    assert_not location.valid?
    assert_includes location.errors[:parent], "must belong to the same universe"
  end

  test "rejects a universe change while child locations exist" do
    location = Location.create!(universe: universes(:universe_one), name: "Parent")
    Location.create!(universe: universes(:universe_one), name: "Child", parent: location)

    assert_not location.update(universe: universes(:universe_two))
    assert_includes location.errors[:universe_id], "cannot be changed while child records exist"
    assert_equal universes(:universe_one).id, location.reload.universe_id
  end

  test "allows a universe change without dependents" do
    location = Location.create!(universe: universes(:universe_one), name: "Mover")

    assert location.update(universe: universes(:universe_two))
    assert_equal universes(:universe_two).id, location.reload.universe_id
  end

  test "the search body is the summary and the description" do
    location = Location.new(universe: universes(:universe_one), name: "The Keep",
      summary: "An old keep on the coast.",
      description: "## Sensory\n\nAn old keep that smells of pipeweed.")

    assert_equal "An old keep on the coast. ## Sensory\n\nAn old keep that smells of pipeweed.",
      location.search_description
  end

  test "a blank description and summary are left out of the search body rather than joined as empty words" do
    location = Location.create!(universe: universes(:universe_one), name: "Empty Keep")

    assert_empty location.search_description
  end
end
