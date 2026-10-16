require "test_helper"

# The summaries are the reader's only account of what narrowed a list, so an
# empty result can always name the value that produced it. They are chrome, which
# is why they live in a helper rather than on the filter: most of their values
# come from the workspace's own path objects, and a filter has no business
# holding a Section or a tag hierarchy.
class CharactersHelperTest < ActionView::TestCase
  setup do
    @universe = universes(:universe_one)
    @character_tags = @universe.character_tags.reorder(:position, :id).to_a
    @character_tag_paths = CharacterTagPaths.build(@character_tags)
  end

  test "an unfiltered list describes nothing" do
    assert_empty summaries
  end

  test "describes each active filter with a readable label" do
    assert_equal [ "Search: “cave”" ], summaries(q: "cave")
  end

  test "names a tag by its full path rather than a leaf another branch may repeat" do
    nested = @character_tags.find { |tag| tag.parent_id.present? }

    assert_equal [ "Character tag: Character tag one / Character tag child" ],
      summaries(character_tag_id: nested.id)
  end

  test "describes the chosen order, because a reader who got nothing back needs to know it was applied" do
    assert_equal [ "Order: Recently edited first" ], summaries(sort: "updated")
    assert_empty summaries(sort: CharacterFilter::DEFAULT_SORT),
      "the order the list already had is not something the reader needs to be told about"
  end

  test "describes every active filter at once, in the order the search area lists them" do
    list = summaries(q: "cave", character_tag_id: @character_tags.first.id, sort: "created")

    assert_equal 3, list.size
    assert_match(/\ASearch: /, list.first)
    assert_match(/\ACharacter tag: /, list.second)
    assert_match(/\AOrder: /, list.third)
  end

  private
    def summaries(**params)
      character_filter_summaries(CharacterFilter.new(params, character_tags: @character_tags))
    end
end
