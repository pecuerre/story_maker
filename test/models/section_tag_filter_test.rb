require "test_helper"

# The Section Tag taxonomy filter narrows this story's tag tree by text alone,
# so it keeps the drag order and offers no reader-chosen sort.
class SectionTagFilterTest < ActiveSupport::TestCase
  setup do
    @story = stories(:story_one)
    @section_tags = @story.section_tags.reorder(:position, :id).to_a

    @tag_one = section_tags(:section_tag_one)
    @tag_two = section_tags(:section_tag_two)
  end

  test "an empty filter changes nothing, keeps the drag order, and reports itself inactive" do
    filter = filter_for

    assert_not filter.active?
    assert_not filter.narrowed?
    assert_empty filter.query_params
    assert_empty filter.discarded
    assert_not SectionTagFilter.sortable?
    assert_nil filter.sort
    assert_equal Set.new([ "Section tag one", "Section tag two" ]), Set.new(apply(filter).map(&:name))
  end

  test "free text matches the name or the description, ignoring case" do
    @tag_one.update!(description: "Book, chapter, or act")

    assert_equal [ "Section tag one" ], apply(filter_for(q: "chapter")).map(&:name)
    assert_equal [ "Section tag one" ], apply(filter_for(q: "CHAPTER")).map(&:name),
      "a search box ignores case"
    assert_empty apply(filter_for(q: "no such tag")).map(&:name)
  end

  test "search text is matched literally, so a wildcard is not a wildcard" do
    @tag_one.update!(name: "Act I")

    assert_equal [ "Act I" ], apply(filter_for(q: "Act I")).map(&:name)
    assert_equal [ "Act I" ], apply(filter_for(q: "Act")).map(&:name),
      "a search box matches part of a name"
    assert_empty apply(filter_for(q: "no such tag")).map(&:name)
  end

  test "another story's tags are outside this tree altogether" do
    assert_empty apply(filter_for(q: "Section tag three")).map(&:name),
      "story two's tag is not in this story's taxonomy"
  end

  test "an order is never offered, so a hand-edited sort key cannot reach the query" do
    forged = filter_for(sort: "name")

    assert_not forged.active?
    assert_not forged.narrowed?
    assert_nil forged.sort
    assert_empty forged.discarded
    assert_equal Set.new([ "Section tag one", "Section tag two" ]), Set.new(apply(forged).map(&:name)),
      "a tree keeps the order it was dragged in"
  end

  test "query_params carries only the filters that are really in effect" do
    assert_equal({ q: "keeper" }, filter_for(q: "  keeper  ").query_params)
    assert_equal({}, filter_for(sort: "name").query_params)
  end

  private
    def filter_for(**params)
      SectionTagFilter.new(params)
    end

    def apply(filter)
      filter.apply(@story.section_tags).to_a
    end
end
