require "test_helper"

# A request acts on the object it authorized, and nothing else.
#
# **`Current.universe` is the universe the request authorized.** `set_current_universe`
# resolves it from the slug and `UniverseAuthorization` answers the access question
# about that one object. A controller that goes back to the database for its own
# `@universe` is asking the same question twice, and the two answers are allowed to
# disagree: the second lookup runs two callbacks later, so a slug that is renamed
# and then taken over in between resolves to a *different* universe — one nobody
# authorized, and one the writer may not touch at all.
#
# That is not a theoretical race. The case below drives it deterministically: it
# renames the universe away and hands its slug to somebody else's, the instant the
# request's own lookup returns. Before this was fixed the request answered 303 and
# wrote the rename into **the other universe**, across the boundary
# [ADR 0005](docs/adr/0005-universe-access-levels.md) draws.
#
# The same rule holds one level down for stories. `set_current_story` resolves
# `Current.story` and has already refused a story in another universe; a
# story-scoped controller that re-finds it reads a second object for one story, and
# the only observable sign is the duplicated query the count cases below pin.
class AuthorizeOnceActOnItTest < ActionDispatch::IntegrationTest
  SLUG_LOOKUP = /FROM "universes" WHERE "universes"\."deleted_at" IS NULL AND "universes"\."slug"/
  STORY_LOOKUP = /FROM "stories" WHERE "stories"\."deleted_at" IS NULL AND "stories"\."universe_id" = \? AND "stories"\."id" = \?/

  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  # --- the universe half -------------------------------------------------------

  test "a settings save writes the universe the request authorized" do
    theirs = Universe.create!(owner: users(:user_two), name: "Theirs", slug: "theirs")
    path = universe_path(universe_slug: @universe.slug)

    rename_away_under_the_request(moved: @universe, taken_over_by: theirs) do
      patch path, params: { universe: { name: "Renamed by its own admin" } }
    end

    assert_response :see_other
    assert_equal "Renamed by its own admin", @universe.reload.name,
      "the write must land on the universe whose access level was checked"
    assert_equal "Theirs", theirs.reload.name,
      "a universe the writer has no membership in must not be written at all"
  end

  test "a settings delete soft-deletes the universe the request authorized" do
    theirs = Universe.create!(owner: users(:user_two), name: "Theirs", slug: "theirs")
    path = universe_path(universe_slug: @universe.slug)

    rename_away_under_the_request(moved: @universe, taken_over_by: theirs) do
      delete path
    end

    assert_response :see_other
    assert @universe.reload.deleted?, "the delete must land on the authorized universe"
    assert_not theirs.reload.deleted?, "a universe the writer has no membership in must not be deleted"
  end

  test "a settings page shows the universe the request authorized" do
    theirs = Universe.create!(owner: users(:user_two), name: "Theirs", slug: "theirs")
    path = edit_universe_path(universe_slug: @universe.slug)

    rename_away_under_the_request(moved: @universe, taken_over_by: theirs) do
      get path
    end

    assert_response :success
    assert_select "input#universe_name[value=?]", "Universe one"
    assert_select "input#universe_name[value=?]", "Theirs", count: 0
  end

  test "a universe-scoped page reads the authorized universe once" do
    # The count is absolute because it is a fact about one query, not about the
    # layout: the sidebar and `Current` add queries of their own to every page, and
    # this one is the request resolving the slug its own URL named.
    assert_equal 1, count_queries(SLUG_LOOKUP) { get universe_path(universe_slug: @universe.slug) }
    assert_equal 1, count_queries(SLUG_LOOKUP) { get edit_universe_path(universe_slug: @universe.slug) }
  end

  # --- the story half ----------------------------------------------------------

  test "a story-scoped page reads the story the request already resolved once" do
    # Every controller below `set_current_story` used to re-find the story, so each
    # of these pages issued the identical query twice. One is now the whole cost,
    # and it is one because the request already holds the row.
    pages = {
      "the story" => universe_story_path(universe_slug: @universe.slug, id: @story.id),
      "its sections" => universe_story_sections_path(universe_slug: @universe.slug, story_id: @story.id),
      "its scenes" => universe_story_scenes_path(universe_slug: @universe.slug, story_id: @story.id)
    }

    pages.each do |label, path|
      get path
      assert_response :success, "#{label} should render"

      assert_equal 1, count_queries(STORY_LOOKUP) { get path },
        "#{label} must not look the story up a second time"
    end
  end

  test "a story from another universe is still a 404" do
    # The second lookup was never what answered a cross-scope story — `set_current_story`
    # did, before it. Removing it must not loosen that, so the answer is pinned here.
    elsewhere = universes(:universe_two).stories.order(:id).first

    get universe_story_scenes_path(universe_slug: @universe.slug, story_id: elsewhere.id)

    assert_response :not_found
  end

  private

    # The concurrent rename, made to happen at exactly the point that decides whether
    # the request can be exploited: the instant its own slug lookup returns.
    #
    # `update_column` rather than `update!` because a rename here is the other
    # request's business — it must not run `HasSlug`, validations, callbacks, or the
    # search reindex, and it must not be re-derived from a name.
    def rename_away_under_the_request(moved:, taken_over_by:)
      original = moved.slug
      fired = false

      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
        payload = args.last
        next if fired || payload[:name] == "SCHEMA"
        next unless payload[:sql].match?(SLUG_LOOKUP)

        fired = true
        moved.update_column(:slug, "#{original}-moved-elsewhere")
        taken_over_by.update_column(:slug, original)
      end

      yield
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
end
