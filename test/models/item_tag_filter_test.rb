require "test_helper"

# The Item Tag taxonomy filter narrows by text alone on a tree, so it keeps
# the drag order and offers no reader-chosen sort.
class ItemTagFilterTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @item_tags = @universe.item_tags.reorder(:position, :id).to_a

    @tag_one = item_tags(:item_tag_one)
    @tag_two = item_tags(:item_tag_two)
  end

  test "an empty filter changes nothing, keeps the drag order, and reports itself inactive" do
    filter = filter_for

    assert_not filter.active?
    assert_not filter.narrowed?
    assert_empty filter.query_params
    assert_empty filter.discarded
    assert_not ItemTagFilter.sortable?
    assert_nil filter.sort
    assert_equal Set.new([ "Item tag one", "Item tag two" ]), Set.new(apply(filter).map(&:name))
  end

  test "free text matches the name or the description, ignoring case" do
    @tag_one.update!(description: "Objects that belonged to someone")

    assert_equal [ "Item tag one" ], apply(filter_for(q: "belonged")).map(&:name)
    assert_equal [ "Item tag one" ], apply(filter_for(q: "BELONGED")).map(&:name),
      "a search box ignores case"
    assert_empty apply(filter_for(q: "no such tag")).map(&:name)
  end

  test "search text is matched literally, so a wildcard is not a wildcard" do
    @tag_one.update!(name: "50/50")

    assert_equal [ "50/50" ], apply(filter_for(q: "50/50")).map(&:name)
    assert_equal [ "50/50" ], apply(filter_for(q: "/")).map(&:name),
      "a slash is text to search for, not a pattern"
    assert_empty apply(filter_for(q: "no such tag")).map(&:name)
  end

  test "an order is never offered, so a hand-edited sort key cannot reach the query" do
    forged = filter_for(sort: "name")

    assert_not forged.active?
    assert_not forged.narrowed?
    assert_nil forged.sort
    assert_empty forged.discarded
    assert_equal Set.new([ "Item tag one", "Item tag two" ]), Set.new(apply(forged).map(&:name)),
      "a tree keeps the order it was dragged in"
  end

  test "query_params carries only the filters that are really in effect" do
    assert_equal({ q: "keeper" }, filter_for(q: "  keeper  ").query_params)
    assert_equal({}, filter_for(sort: "name").query_params)
  end

  private
    def filter_for(**params)
      ItemTagFilter.new(params)
    end

    def apply(filter)
      filter.apply(@universe.item_tags).to_a
    end
end
