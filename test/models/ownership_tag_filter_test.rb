require "test_helper"

# The Ownership Tag taxonomy filter narrows by text alone on a tree, so it keeps
# the drag order and offers no reader-chosen sort.
class OwnershipTagFilterTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @ownership_tags = @universe.ownership_tags.reorder(:position, :id).to_a

    @tag_one = ownership_tags(:ownership_tag_one)
    @tag_two = ownership_tags(:ownership_tag_two)
  end

  test "an empty filter changes nothing, keeps the drag order, and reports itself inactive" do
    filter = filter_for

    assert_not filter.active?
    assert_not filter.narrowed?
    assert_empty filter.query_params
    assert_empty filter.discarded
    assert_not OwnershipTagFilter.sortable?
    assert_nil filter.sort
    assert_equal Set.new([ "Ownership tag one", "Ownership tag two" ]), Set.new(apply(filter).map(&:name))
  end

  test "free text matches the name or the description, ignoring case" do
    @tag_one.update!(description: "What kind of ownership is being recorded")

    assert_equal [ "Ownership tag one" ], apply(filter_for(q: "recorded")).map(&:name)
    assert_equal [ "Ownership tag one" ], apply(filter_for(q: "RECORDED")).map(&:name),
      "a search box ignores case"
    assert_empty apply(filter_for(q: "no such tag")).map(&:name)
  end

  test "search text is matched literally, so a wildcard is not a wildcard" do
    @tag_one.update!(name: "Lifetime loan")

    assert_equal [ "Lifetime loan" ], apply(filter_for(q: "Lifetime loan")).map(&:name)
    assert_equal [ "Lifetime loan" ], apply(filter_for(q: "loan")).map(&:name),
      "a search box matches part of a name"
    assert_empty apply(filter_for(q: "no such tag")).map(&:name)
  end

  test "an order is never offered, so a hand-edited sort key cannot reach the query" do
    forged = filter_for(sort: "name")

    assert_not forged.active?
    assert_not forged.narrowed?
    assert_nil forged.sort
    assert_empty forged.discarded
    assert_equal Set.new([ "Ownership tag one", "Ownership tag two" ]), Set.new(apply(forged).map(&:name)),
      "a tree keeps the order it was dragged in"
  end

  test "query_params carries only the filters that are really in effect" do
    assert_equal({ q: "keeper" }, filter_for(q: "  keeper  ").query_params)
    assert_equal({}, filter_for(sort: "name").query_params)
  end

  private
    def filter_for(**params)
      OwnershipTagFilter.new(params)
    end

    def apply(filter)
      filter.apply(@universe.ownership_tags).to_a
    end
end
