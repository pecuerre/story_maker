require "test_helper"

# The top-bar search as a request. Two formats, one read: HTML for the results
# page a reader can open, share, and use without scripting, and JSON for the
# dropdown.
class SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  # A hit as the engine would answer it, in the universe the request is scoped to.
  def hit(title: "Hannah", kind: "character", body: "A mother who disappears", universe: @universe, story: nil)
    SearchTestBackend.document(
      id: "#{kind}-1", kind: kind, title: title,
      universe_id: universe.id, story_id: story&.id, body: body,
      url: "/u/#{universe.slug}/characters/1"
    )
  end

  test "the results page states what was searched" do
    stub_search_backend(hits: [ hit ])

    get universe_search_path(universe_slug: @universe.slug), params: { q: "hannah" }

    assert_response :success
    assert_select ".page-title", text: "Search"
    assert_select ".search-page-scope-note", text: /This universe/
    assert_select ".search-result-title", text: "Hannah"
    assert_select ".search-result-kind", text: "Character"
    assert_select ".search-result-context", text: @universe.name
    assert_select ".search-result-snippet", text: /disappears/
  end

  test "the page is reachable without a universe, and searches the whole platform" do
    stub_search_backend(hits: [ hit(universe: universes(:universe_two)) ])

    get search_path, params: { q: "hannah" }

    assert_response :success
    assert_select ".search-page-scope-note", text: /Entire platform/
  end

  test "an empty search explains the scope instead of showing an empty result" do
    stub_search_backend

    get universe_search_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".search-empty h2", text: /Search this universe/
    assert_select ".search-result", count: 0
  end

  test "one character says to keep typing rather than that nothing matched" do
    stub_search_backend

    get universe_search_path(universe_slug: @universe.slug), params: { q: "h" }

    assert_response :success
    assert_select ".search-empty h2", text: "Keep typing"
  end

  test "a query too short to search offers no commands either" do
    # A one-character query that returned destinations but no records would make
    # two different statements about the same question.
    stub_search_backend

    get universe_search_path(universe_slug: @universe.slug, format: :json), params: { q: "w" }

    assert_response :success
    assert_empty response.parsed_body["commands"]
    assert_equal 0, response.parsed_body["total"]
  end

  test "a search that matched nothing says so, and suggests widening" do
    stub_search_backend

    get universe_search_path(universe_slug: @universe.slug), params: { q: "zzzznotathing" }

    assert_response :success
    assert_select ".search-empty h2", text: /Nothing matched/
    assert_select ".search-empty", text: /Entire platform/
  end

  test "navigation commands are offered beside the results" do
    stub_search_backend(hits: [ hit ])

    get universe_search_path(universe_slug: @universe.slug), params: { q: "chara" }

    assert_response :success
    assert_select ".search-commands h2", text: "Go to"
    assert_select ".search-command", text: "Characters"
  end

  test "a scope narrowed to one kind offers no commands, because it already said what it wanted" do
    stub_search_backend(hits: [ hit ])

    get universe_search_path(universe_slug: @universe.slug), params: { q: "hannah", scope: "characters" }

    assert_response :success
    assert_select ".search-commands", count: 0
  end

  test "the JSON answer carries the result count, the scope, and the results" do
    stub_search_backend(hits: [ hit ])

    get universe_search_path(universe_slug: @universe.slug, format: :json), params: { q: "hannah" }

    assert_response :success
    payload = response.parsed_body

    assert payload["available"]
    assert_equal "hannah", payload["query"]
    assert_equal "universe", payload["scope"]
    assert_equal "This universe", payload["scope_label"]
    assert_equal 1, payload["total"]
    assert_equal [ "character-1" ], payload["results"].pluck("id")
    assert_equal "Hannah", payload["results"].first["title"]
    assert_equal "Character", payload["results"].first["kind_label"]
    assert_equal @universe.name, payload["results"].first["subtitle"]
    assert_equal "/u/one/characters/1", payload["results"].first["url"]
  end

  test "the JSON answer carries commands for a boundary search" do
    stub_search_backend

    get search_path(format: :json), params: { q: "universe" }

    assert_response :success
    # The landing page's commands are the universes this reader may open, which is
    # the same set a platform search is filtered to.
    assert_equal [ "Universe: Universe one", "Universe: Universe two" ],
      response.parsed_body["commands"].pluck("title")
  end

  test "the landing page offers no universe a private guest cannot see" do
    Universe.create!(owner: users(:user_two), name: "Hidden", private: true)
    stub_search_backend
    sign_out

    get search_path(format: :json), params: { q: "universe" }

    assert_response :success
    assert_not_includes response.parsed_body["commands"].pluck("title"), "Universe: Hidden"
  end

  test "the dropdown asks for fewer results than the page, and the page can be asked for a later one" do
    stub_search_backend(hits: [ hit ])

    get universe_search_path(universe_slug: @universe.slug, format: :json), params: { q: "hannah" }
    assert_equal Search::Catalog::DROPDOWN_LIMIT, search_backend.searches.last[:limit]
    assert_equal 0, search_backend.searches.last[:offset]

    get universe_search_path(universe_slug: @universe.slug), params: { q: "hannah", page: "3" }
    assert_equal Search::Catalog::PAGE_LIMIT, search_backend.searches.last[:limit]
    assert_equal 2 * Search::Catalog::PAGE_LIMIT, search_backend.searches.last[:offset]
  end

  test "an engine that is not configured is stated on the page instead of failing it" do
    stub_search_backend(available: false)

    get universe_search_path(universe_slug: @universe.slug), params: { q: "hannah" }

    assert_response :success
    assert_select ".search-empty h2", text: "Search is not available"
    assert_select ".search-empty", text: /MEILISEARCH_URL/
  end

  test "an engine that is not configured is stated in the JSON answer" do
    stub_search_backend(available: false)

    get universe_search_path(universe_slug: @universe.slug, format: :json), params: { q: "hannah" }

    assert_response :success
    payload = response.parsed_body
    assert_not payload["available"]
    assert_match(/MEILISEARCH_URL/, payload["reason"])
    assert_empty payload["results"]
  end

  test "a dropped value is reported instead of silently changing the search" do
    stub_search_backend

    get universe_search_path(universe_slug: @universe.slug),
      params: { q: "hannah", scope: "story", story_id: stories(:story_two).id }

    assert_response :success
    assert_select ".alert", text: /not a story of this universe/
  end

  test "an unrecognized scope is reported too" do
    stub_search_backend

    get universe_search_path(universe_slug: @universe.slug), params: { q: "hannah", scope: "planets" }

    assert_response :success
    assert_select ".alert", text: /is not a search scope/
  end

  test "searching inside a story does not change the story the workspace is in" do
    stub_search_backend
    sign_out

    # No story is remembered yet.
    get universe_characters_path(universe_slug: @universe.slug)
    get universe_search_path(universe_slug: @universe.slug),
      params: { q: "hannah", scope: "story", story_id: @story.id }

    assert_response :success
    # The story search resolved the story as its boundary...
    assert_equal "story_id = #{@story.id}", search_backend.searches.last[:filter]
    # ...and the page is still the character list, with no story chosen.
    assert_select "aside.workspace-sidebar a.sidebar-link.active", count: 0
    assert_select "nav .navbar-nav .nav-item", 1
  end

  test "a guest may search a public universe" do
    stub_search_backend(hits: [ hit ])
    sign_out

    get universe_search_path(universe_slug: @universe.slug), params: { q: "hannah" }

    assert_response :success
    assert_select ".search-result-title", text: "Hannah"
  end

  test "a guest may not search a private universe" do
    private_universe = Universe.create!(owner: users(:user_two), name: "Hidden", private: true)
    sign_out

    get universe_search_path(universe_slug: private_universe.slug), params: { q: "hannah" }

    # Neither a guest nor a signed-in stranger is told the universe exists.
    assert_response :not_found
  end

  test "a signed-in reader with no access to a private universe is not told it exists" do
    private_universe = Universe.create!(owner: users(:user_two), name: "Hidden", private: true)

    get universe_search_path(universe_slug: private_universe.slug), params: { q: "hannah" }

    assert_response :not_found
  end

  test "a read-only member may search" do
    private_universe = Universe.create!(owner: users(:user_two), name: "Hidden", private: true)
    UniverseMembership.create!(universe: private_universe, user: users(:user_one), access_level: :read)
    stub_search_backend(hits: [ hit(universe: private_universe) ])

    get universe_search_path(universe_slug: private_universe.slug), params: { q: "hannah" }

    assert_response :success
    assert_select ".search-result-title", text: "Hannah"
  end

  test "a search never mutates, so it needs no CSRF token" do
    stub_search_backend(hits: [ hit ])

    with_forgery_protection do
      get universe_search_path(universe_slug: @universe.slug, format: :json), params: { q: "hannah" }
      assert_response :success
    end
  end

  test "the search box is on every page, and the scope it offers follows the page" do
    stub_search_backend

    [ search_path, universe_search_path(universe_slug: @universe.slug) ].each do |path|
      get path

      assert_response :success
      assert_select "nav form.navbar-search[data-controller=search]", 1
      assert_select "nav form.navbar-search[action=?]", path
      assert_select "nav input[name=q][role=combobox]", 1
      assert_select "nav select[name=scope] option", Search::Scope::VALUES.size
    end
  end

  test "a scope the page cannot honour is disabled rather than hidden" do
    stub_search_backend

    get search_path

    assert_response :success
    assert_select "nav select[name=scope] option[value=universe][disabled]", 1
    assert_select "nav select[name=scope] option[value=story][disabled]", 1
    # And the widest boundary that does exist is what the box offers by default.
    assert_select "nav select[name=scope] option[value=platform][selected]", 1
  end

  test "a universe page offers its own and its story's scopes" do
    stub_search_backend
    get universe_story_path(universe_slug: @universe.slug, id: @story.id)

    assert_response :success
    assert_select "nav select[name=scope] option[value=universe][selected]:not([disabled])", 1
    assert_select "nav select[name=scope] option[value=story]:not([disabled])", 1
    assert_select "nav form.navbar-search input[name=story_id][value=?]", @story.id.to_s
  end

  test "the results page carries the story boundary so the scope can be narrowed without a new form" do
    stub_search_backend
    get universe_story_path(universe_slug: @universe.slug, id: @story.id)

    get universe_search_path(universe_slug: @universe.slug), params: { q: "hannah", scope: "story" }

    assert_response :success
    assert_select "form[action=?] input[name=story_id][value=?]",
      universe_search_path(universe_slug: @universe.slug), @story.id.to_s
  end

  test "the box keeps the resolved scope, not the requested one, after a widening" do
    stub_search_backend

    get universe_search_path(universe_slug: @universe.slug), params: { q: "hannah", scope: "story" }

    assert_response :success
    # The page's own form says what was really searched...
    assert_select "form[action=?] select[name=scope] option[value=universe][selected]",
      universe_search_path(universe_slug: @universe.slug)
    # ...and so does the box in the top bar.
    assert_select "nav select[name=scope] option[value=universe][selected]", 1
  end

  test "a page number beyond the index's own limit is refused rather than asked for" do
    stub_search_backend

    get universe_search_path(universe_slug: @universe.slug), params: { q: "hannah", page: "999" }

    assert_response :success
    assert_operator search_backend.searches.last[:offset], :<, Search::Client::SETTINGS[:pagination][:maxTotalHits]
  end
end
