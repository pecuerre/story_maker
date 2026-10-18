require "test_helper"

# The Relation Tag taxonomy filter narrows by text alone on a tree, so it keeps
# the drag order and offers no reader-chosen sort.
class RelationTagFilterTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @relation_tags = @universe.relation_tags.reorder(:position, :id).to_a

    @tag_one = relation_tags(:relation_tag_one)
    @tag_two = relation_tags(:relation_tag_two)
  end

  test "an empty filter changes nothing, keeps the drag order, and reports itself inactive" do
    filter = filter_for

    assert_not filter.active?
    assert_not filter.narrowed?
    assert_empty filter.query_params
    assert_empty filter.discarded
    assert_not RelationTagFilter.sortable?
    assert_nil filter.sort
    assert_equal Set.new([ "Relation tag one", "Relation tag two" ]), Set.new(apply(filter).map(&:name))
  end

  test "free text matches the name or the description, ignoring case" do
    @tag_one.update!(description: "How two characters feel about each other")

    assert_equal [ "Relation tag one" ], apply(filter_for(q: "feel")).map(&:name)
    assert_equal [ "Relation tag one" ], apply(filter_for(q: "FEEL")).map(&:name),
      "a search box ignores case"
    assert_empty apply(filter_for(q: "no such tag")).map(&:name)
  end

  test "search text is matched literally, so a wildcard is not a wildcard" do
    @tag_one.update!(name: "100% certain")

    assert_equal [ "100% certain" ], apply(filter_for(q: "100%")).map(&:name)
    assert_equal [ "100% certain" ], apply(filter_for(q: "%")).map(&:name),
      "a percent sign is text to search for, not a pattern matching everything"
  end

  test "an order is never offered, so a hand-edited sort key cannot reach the query" do
    forged = filter_for(sort: "name")

    assert_not forged.active?
    assert_not forged.narrowed?
    assert_nil forged.sort
    assert_empty forged.discarded
    assert_equal Set.new([ "Relation tag one", "Relation tag two" ]), Set.new(apply(forged).map(&:name)),
      "a tree keeps the order it was dragged in"
  end

  test "query_params carries only the filters that are really in effect" do
    assert_equal({ q: "keeper" }, filter_for(q: "  keeper  ").query_params)
    assert_equal({}, filter_for(sort: "name").query_params)
  end

  private
    def filter_for(**params)
      RelationTagFilter.new(params)
    end

    def apply(filter)
      filter.apply(@universe.relation_tags).to_a
    end
end
