require "test_helper"

# The Character Tag taxonomy filter is a value object, and it is worth covering
# on its own because the request tests can only show the outcome. It is the
# first filter on a **tag tree**, so it narrows by text alone and offers no
# reader-chosen order: a tree keeps the order it was dragged in.
class CharacterTagFilterTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @character_tags = @universe.character_tags.reorder(:position, :id).to_a

    @tag_one = character_tags(:character_tag_one)
    @tag_two = character_tags(:character_tag_two)
  end

  test "an empty filter changes nothing, keeps the drag order, and reports itself inactive" do
    filter = filter_for

    assert_not filter.active?
    assert_not filter.narrowed?
    assert_empty filter.query_params
    assert_empty filter.discarded
    assert_not CharacterTagFilter.sortable?
    assert_nil filter.sort
    assert_equal Set.new([ "Character tag one", "Character tag two", "Character tag child" ]), Set.new(apply(filter).map(&:name))
  end

  test "free text matches the name or the description, ignoring case" do
    @tag_one.update!(description: "The kind of person Ariadne is")

    assert_equal [ "Character tag one" ], apply(filter_for(q: "kind")).map(&:name)
    assert_equal [ "Character tag one" ], apply(filter_for(q: "KIND")).map(&:name),
      "a search box ignores case"
    assert_empty apply(filter_for(q: "no such tag")).map(&:name),
      "text that matches nothing empties the list"
  end

  test "search text is matched literally, so a wildcard is not a wildcard" do
    @tag_one.update!(name: "50% chance")

    assert_equal [ "50% chance" ], apply(filter_for(q: "50%")).map(&:name)
    assert_equal [ "50% chance" ], apply(filter_for(q: "%")).map(&:name),
      "a percent sign is text to search for, not a pattern matching everything"
  end

  test "an order is never offered, so a hand-edited sort key cannot reach the query" do
    forged = filter_for(sort: "name")

    assert_not forged.active?
    assert_not forged.narrowed?
    assert_nil forged.sort
    assert_empty forged.discarded
    assert_equal Set.new([ "Character tag one", "Character tag two", "Character tag child" ]), Set.new(apply(forged).map(&:name)),
      "a tree keeps the order it was dragged in"
  end

  test "tags from another universe never appear, because the scope is already fixed" do
    assert_empty apply(filter_for(q: "Character tag three")).map(&:name),
      "another universe's tag is outside this list altogether"
  end

  test "query_params carries only the filters that are really in effect" do
    assert_equal({ q: "keeper" }, filter_for(q: "  keeper  ").query_params)
    assert_equal({}, filter_for(sort: "name").query_params)
  end

  private
    def filter_for(**params)
      CharacterTagFilter.new(params)
    end

    def apply(filter)
      filter.apply(@universe.character_tags).to_a
    end
end
