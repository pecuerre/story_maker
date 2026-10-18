require "test_helper"

# The Location Tag taxonomy filter narrows by text alone on a tree, so it keeps
# the drag order and offers no reader-chosen sort.
class LocationTagFilterTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @location_tags = @universe.location_tags.reorder(:position, :id).to_a

    @tag_one = location_tags(:location_tag_one)
    @tag_two = location_tags(:location_tag_two)
  end

  test "an empty filter changes nothing, keeps the drag order, and reports itself inactive" do
    filter = filter_for

    assert_not filter.active?
    assert_not filter.narrowed?
    assert_empty filter.query_params
    assert_empty filter.discarded
    assert_not LocationTagFilter.sortable?
    assert_nil filter.sort
    assert_equal Set.new([ "Location tag one", "Location tag two" ]), Set.new(apply(filter).map(&:name))
  end

  test "free text matches the name or the description, ignoring case" do
    @tag_one.update!(description: "Group places and regions under one label")

    assert_equal [ "Location tag one" ], apply(filter_for(q: "label")).map(&:name)
    assert_equal [ "Location tag one" ], apply(filter_for(q: "LABEL")).map(&:name),
      "a search box ignores case"
    assert_empty apply(filter_for(q: "no such tag")).map(&:name)
  end

  test "search text is matched literally, so a wildcard is not a wildcard" do
    @tag_one.update!(name: "North & South")

    assert_equal [ "North & South" ], apply(filter_for(q: "North & South")).map(&:name)
    assert_equal [ "North & South" ], apply(filter_for(q: "&")).map(&:name),
      "an ampersand is text to search for, not a pattern"
    assert_empty apply(filter_for(q: "no such tag")).map(&:name)
  end

  test "an order is never offered, so a hand-edited sort key cannot reach the query" do
    forged = filter_for(sort: "name")

    assert_not forged.active?
    assert_not forged.narrowed?
    assert_nil forged.sort
    assert_empty forged.discarded
    assert_equal Set.new([ "Location tag one", "Location tag two" ]), Set.new(apply(forged).map(&:name)),
      "a tree keeps the order it was dragged in"
  end

  test "query_params carries only the filters that are really in effect" do
    assert_equal({ q: "keeper" }, filter_for(q: "  keeper  ").query_params)
    assert_equal({}, filter_for(sort: "name").query_params)
  end

  private
    def filter_for(**params)
      LocationTagFilter.new(params)
    end

    def apply(filter)
      filter.apply(@universe.location_tags).to_a
    end
end
