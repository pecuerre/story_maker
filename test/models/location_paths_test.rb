require "test_helper"

class LocationPathsTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @region = @universe.locations.create!(name: "Winden", position: 0)
    @house = @universe.locations.create!(name: "Jonas House", position: 1, parent: @region)
    @room = @universe.locations.create!(name: "Jonas Room", position: 2, parent: @house)
    @paths = LocationPaths.build(@universe.locations.reorder(:position, :id).to_a)
  end

  test "labels a place with its full ancestor path" do
    assert_equal "Winden", @paths.label_for(@region)
    assert_equal "Winden / Jonas House", @paths.label_for(@house)
    assert_equal "Winden / Jonas House / Jonas Room", @paths.label_for(@room)
  end

  test "accepts a bare id and rejects an unknown or blank one" do
    assert_equal "Winden / Jonas House", @paths.label_for(@house.id)
    assert_nil @paths.label_for(0)
    assert_nil @paths.label_for(nil)
  end

  test "offers indented choices in root-first order so a child follows its parent" do
    # Only the three places this test created, in the order the tree reaches them.
    created = [ @region.id, @house.id, @room.id ]
    created_choices = @paths.choices.select { |_, id| created.include?(id) }

    assert_equal [ [ "Winden", @region.id ], [ "— Jonas House", @house.id ], [ "— — Jonas Room", @room.id ] ],
      created_choices
  end

  test "a separate tree is unaffected and its own ids are all it knows" do
    other = universes(:universe_two).locations.create!(name: "Elsewhere", position: 0)
    other_paths = LocationPaths.build([ other ])

    assert_equal "Elsewhere", other_paths.label_for(other)
    assert_nil other_paths.label_for(@region)
  end
end
