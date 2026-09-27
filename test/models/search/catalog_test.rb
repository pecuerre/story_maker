require "test_helper"

# Running a query: which filter reaches the engine, when the engine is not asked
# at all, and how a hit is described for a reader.
#
# Authorization is the point of most of this. A platform search is filtered to the
# universes the reader may read *in the request to the engine*, so a private
# record is never fetched and then hidden.
class Search::CatalogTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @user = users(:user_one)
  end

  test "a universe search asks only for that universe" do
    backend = stub_search_backend
    catalog = Search::Catalog.new(backend: backend, user: @user)

    catalog.results(Search::Query.new({ q: "hannah" }, universe: @universe))

    assert_equal "universe_id = #{@universe.id}", backend.searches.sole[:filter]
  end

  test "a story search asks only for that story" do
    backend = stub_search_backend
    catalog = Search::Catalog.new(backend: backend, user: @user)
    query = Search::Query.new({ q: "hannah", scope: "story", story_id: @story.id }, universe: @universe)

    catalog.results(query)

    assert_equal "story_id = #{@story.id}", backend.searches.sole[:filter]
  end

  test "a kind search adds the kind to the boundary" do
    backend = stub_search_backend
    catalog = Search::Catalog.new(backend: backend, user: @user)

    catalog.results(Search::Query.new({ q: "hannah", scope: "characters" }, universe: @universe))

    assert_equal "universe_id = #{@universe.id} AND kind = \"character\"", backend.searches.sole[:filter]
  end

  test "a platform search is filtered to the universes the reader may read" do
    private_universe = Universe.create!(owner: users(:user_two), name: "Hidden", private: true)
    UniverseMembership.create!(universe: private_universe, user: @user, access_level: :read)
    backend = stub_search_backend

    Search::Catalog.new(backend: backend, user: @user).results(Search::Query.new({ q: "hannah" }))

    readable = Universe.visible_to(@user).order(:id).pluck(:id)
    assert_equal "universe_id IN [#{readable.join(", ")}]", backend.searches.sole[:filter]
    assert_includes readable, private_universe.id
  end

  test "a platform search never asks the engine when the reader may read nothing" do
    # Nobody owns a universe and every universe is private, so the readable set is
    # empty. The engine is not asked at all: an unfiltered search would have
    # disclosed every private record in the index.
    Universe.update_all(private: true)
    stranger = User.create!(email_address: "stranger@example.com", password: "password123456", name: "Stranger")
    backend = stub_search_backend

    results = Search::Catalog.new(backend: backend, user: stranger)
      .results(Search::Query.new({ q: "hannah" }))

    assert_empty backend.searches
    assert results.empty?
    assert_equal 0, results.total
  end

  test "a guest's platform search is filtered to the public universes" do
    Universe.create!(owner: users(:user_two), name: "Hidden", private: true)
    backend = stub_search_backend

    Search::Catalog.new(backend: backend, user: nil).results(Search::Query.new({ q: "hannah" }))

    public_ids = Universe.visible_to(nil).order(:id).pluck(:id)
    assert_equal "universe_id IN [#{public_ids.join(", ")}]", backend.searches.sole[:filter]
  end

  test "a query too short to be worth asking never reaches the engine" do
    backend = stub_search_backend

    results = Search::Catalog.new(backend: backend, user: @user)
      .results(Search::Query.new({ q: "h" }, universe: @universe))

    assert_empty backend.searches
    assert results.empty?
  end

  test "an unavailable engine is raised, never answered as an empty result" do
    stub_search_backend(available: false)

    assert_raises(Search::Unavailable) do
      Search::Catalog.new(backend: search_backend, user: @user)
        .results(Search::Query.new({ q: "hannah" }, universe: @universe))
    end
  end

  test "the limit and offset reach the engine unchanged" do
    backend = stub_search_backend

    Search::Catalog.new(backend: backend, user: @user)
      .results(Search::Query.new({ q: "hannah" }, universe: @universe), limit: 25, offset: 50)

    assert_equal 25, backend.searches.sole[:limit]
    assert_equal 50, backend.searches.sole[:offset]
  end

  test "a hit is described with names resolved now, and an excerpt around the match" do
    stub_search_backend(hits: [
      SearchTestBackend.document(id: "character-1", kind: "character", title: "Hannah",
        universe_id: @universe.id, story_id: @story.id,
        body: "A mother who disappears. " * 20)
    ])

    results = Search::Catalog.new(backend: search_backend, user: @user)
      .results(Search::Query.new({ q: "disappears" }, universe: @universe))

    hit = results.hits.sole
    # Ids in the document, names resolved at read time, so a rename cannot leave a
    # stale name in the index.
    assert_equal "#{@story.name} · #{@universe.name}", hit.subtitle
    assert_equal "Character", hit.kind_label
    assert_includes hit.snippet, "disappears"
  end

  test "an excerpt marks that it starts mid-text" do
    body = ("padding " * 40) + "the needle " + ("trailing " * 40)
    stub_search_backend(hits: [
      SearchTestBackend.document(id: "character-1", kind: "character", title: "Hannah",
        universe_id: @universe.id, body: body)
    ])

    results = Search::Catalog.new(backend: search_backend, user: @user)
      .results(Search::Query.new({ q: "needle" }, universe: @universe))

    hit = results.hits.sole
    assert hit.snippet.start_with?("…"), "an excerpt cut from the middle says so: #{hit.snippet.inspect}"
    assert_includes hit.snippet, "needle"
  end

  test "a taxonomy turns a tag into the taxonomy's own tag" do
    stub_search_backend(hits: [
      SearchTestBackend.document(id: "character_tag-1", kind: "tag", taxonomy: "Character",
        title: "Fate", universe_id: @universe.id, url: "/u/one/character_tags/1")
    ])

    results = Search::Catalog.new(backend: search_backend, user: @user)
      .results(Search::Query.new({ q: "fate" }, universe: @universe))

    assert_equal "Character tag", results.hits.sole.kind_label
  end

  test "a field the engine adds is ignored rather than exposed" do
    stub_search_backend(hits: [
      SearchTestBackend.document(id: "character-1", kind: "character", title: "Hannah",
        universe_id: @universe.id).merge("_rankingScore" => 0.99)
    ])

    results = Search::Catalog.new(backend: search_backend, user: @user)
      .results(Search::Query.new({ q: "hannah" }, universe: @universe))

    assert_equal %i[id kind kind_label taxonomy title subtitle snippet url],
      results.hits.sole.as_json.keys
  end

  test "the total comes from the engine, so a short page is not read as everything" do
    stub_search_backend(hits: [])

    results = Search::Catalog.new(backend: search_backend, user: @user)
      .results(Search::Query.new({ q: "hannah" }, universe: @universe))

    assert_equal 0, results.total
    assert results.empty?
    assert_not results.any?
  end
end
