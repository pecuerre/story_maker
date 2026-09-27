require "test_helper"

# The request as a value object: what was asked, what can be used, and what the
# page may say it actually searched. `SceneFilter` is the precedent — a value that
# cannot be used is dropped and reported, never silently emptying a result.
class Search::QueryTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
  end

  test "a plain text search is searchable and canonical" do
    query = Search::Query.new({ q: "  gandalf  ", scope: "universe" }, universe: @universe)

    assert_equal "gandalf", query.text
    assert query.applied?
    assert query.searchable?
    assert_not query.too_short?
    assert_equal({ q: "gandalf", scope: "universe" }, query.query_params)
    assert_empty query.discarded
  end

  test "an empty search is not applied and is not too short" do
    query = Search::Query.new({}, universe: @universe)

    assert_not query.applied?
    assert_not query.searchable?
    assert_not query.too_short?
    assert_equal "universe", query.query_params[:scope]
  end

  test "one character is something typed, not something to search for" do
    query = Search::Query.new({ q: "a" }, universe: @universe)

    assert query.applied?
    assert_not query.searchable?
    assert query.too_short?
  end

  test "a very long query is cut rather than refused" do
    query = Search::Query.new({ q: "a" * 500 }, universe: @universe)

    assert_equal Search::Query::MAXIMUM_LENGTH, query.text.length
    assert query.searchable?
  end

  test "a story boundary is a story of the current universe" do
    query = Search::Query.new({ q: "arrival", scope: "story", story_id: @story.id }, universe: @universe)

    assert_equal @story, query.story
    assert_equal "story", query.boundary
    assert_equal @story.id.to_s, query.query_params[:story_id]
    assert_empty query.discarded
  end

  test "a story id alone does not narrow the search" do
    # The top-bar form always carries the current story so the reader can pick
    # "this story" from the dropdown without a page load. That latent parameter
    # must not silently turn the default universe search into a story search.
    query = Search::Query.new({ q: "arrival", story_id: @story.id }, universe: @universe)

    assert_equal @story, query.story
    assert_equal "universe", query.boundary
  end

  test "a story of another universe is dropped and reported, not searched" do
    query = Search::Query.new({ q: "arrival", story_id: stories(:story_two).id, scope: "story" },
      universe: @universe)

    assert_nil query.story
    assert_equal "universe", query.boundary
    assert_includes query.discarded, "The story filter was ignored because it is not a story of this universe."
    # A dropped story must not survive into a link, or the next request repeats it.
    assert_not_includes query.query_params.keys, :story_id
  end

  test "a story boundary without a universe is dropped and reported" do
    query = Search::Query.new({ q: "arrival", story_id: @story.id }, universe: nil)

    assert_nil query.story
    assert_equal "platform", query.boundary
    assert_includes query.discarded, "The story filter was ignored because no universe is selected."
  end

  test "an unknown story id is dropped like any other unusable value" do
    query = Search::Query.new({ q: "arrival", story_id: "0" }, universe: @universe)

    assert_nil query.story
    assert_equal [ "The story filter was ignored because it is not a story of this universe." ], query.discarded
  end

  test "a requested scope is kept in the URL even when the search is widened" do
    query = Search::Query.new({ q: "arrival", scope: "story" }, universe: @universe)

    # The link the reader gets keeps asking for the story, so choosing one later
    # is one click rather than a new URL to find. The *search* uses the boundary
    # that exists, and says so.
    assert_equal "story", query.scope.value
    assert_equal "universe", query.boundary
    assert_equal [ "The story search was widened to this universe because no story is selected." ],
      query.discarded
  end

  test "the only query keys are the ones a search needs" do
    assert_equal %i[ q scope story_id ], Search::Query::PARAMS
  end
end
