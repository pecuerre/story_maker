require "test_helper"

class NarrativeOrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  def narrative_order_url(story: @story, universe: @universe)
    universe_story_narrative_order_url(universe_slug: universe.slug, story_id: story)
  end

  def narrative_order_path(story: @story, universe: @universe)
    universe_story_narrative_order_path(universe_slug: universe.slug, story_id: story)
  end

  test "renders the comparison for a signed-in reader" do
    get narrative_order_url

    assert_response :success
    assert_select "h1", text: "Narrative order"
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]",
      narrative_order_path, text: "Narrative order"
    assert_select "nav.content-tabs a", text: "Sections"
    assert_select "nav.content-tabs a", text: "Plots"
    assert_select "nav.content-tabs a", text: "Scenes"

    # The left column is narrative order, and it is the story's whole sequence.
    assert_equal [ "Scene one", "Scene two", "Scene three" ],
      css_select("ol.list-group .entity-title").map { |title| title.text.strip }
    assert_select "ol.list-group .badge", text: "First in this run"
    assert_select "ol.list-group .badge", text: "Later"
    assert_select "ol.list-group", text: /No event linked/

    # The right column is the Universe Timeline, with the events this story's
    # scenes depict linked back to their details pages.
    assert_select "a[href=?]", universe_event_path(universe_slug: @universe.slug, id: events(:event_one)), text: "The beginning"
    assert_select "a[href=?]", universe_event_path(universe_slug: @universe.slug, id: events(:event_two)), text: "The end"
  end

  test "the whole timeline is shown, including events this story never depicts" do
    unreferenced = @universe.events.create!(title: "Never depicted", start_datetime: "2026-09-12 12:00")

    get narrative_order_url

    assert_response :success
    assert_select "a[href=?]", universe_event_path(universe_slug: @universe.slug, id: unreferenced), text: "Never depicted"
    assert_select ".timeline-layer", text: /No scene depicts this event/
  end

  test "an event with no recorded time is separated from the numbered timeline rows" do
    bare = @universe.events.create!(title: "Bare event")

    get narrative_order_url

    assert_response :success
    assert_select "h3", text: "No recorded time"
    assert_select "a[href=?]", universe_event_path(universe_slug: @universe.slug, id: bare), text: "Bare event"
    assert_select ".timeline-layer a", text: "Bare event", count: 0
  end

  test "a universe whose events all lack recorded time does not claim to have none" do
    universe = Universe.create!(owner: users(:user_one), name: "Unplaced events", slug: "unplaced-events")
    story = universe.stories.create!(name: "Unplaced story")
    bare = universe.events.create!(title: "Bare event")
    story.scenes.create!(name: "Only scene", position: 0).scene_events.create!(event: bare)

    get narrative_order_url(story: story, universe: universe)

    assert_response :success
    assert_select "p.text-body-secondary", text: "This universe has events, but none has a recorded time yet."
    assert_select "h3", text: "No recorded time"
    assert_select "h2", text: "No events in this universe yet", count: 0
  end

  test "a conflicting scene names both times and the event range" do
    scenes(:scene_one).update!(datetime: "2026-09-11 08:00")

    get narrative_order_url

    assert_response :success
    assert_select "p.text-danger", text: /Conflicting time: this scene's own time \(2026-09-11 08:00\)/
    assert_select "p.text-danger", text: /From 2026-09-11 09:00/
  end

  test "the page offers no mutation controls" do
    get narrative_order_url

    assert_response :success
    assert_select "form[action*='/scenes']", count: 0
    assert_select "form[action*='/narrative_order']", count: 0
  end

  test "another universe's story is a 404" do
    get narrative_order_url(story: stories(:story_two))

    assert_response :not_found
  end

  test "a signed-in non-member of a private universe is refused, and a member can read" do
    private_universe = Universe.create!(owner: users(:user_two), name: "Private comparison",
      slug: "private-comparison", private: true)
    private_story = private_universe.stories.create!(name: "Private story")

    get narrative_order_url(story: private_story, universe: private_universe)
    assert_response :not_found

    UniverseMembership.create!(universe: private_universe, user: users(:user_one), access_level: :read)

    get narrative_order_url(story: private_story, universe: private_universe)
    assert_response :success
  end

  test "a guest is sent to sign in and is not offered the tab" do
    sign_out

    get narrative_order_url
    assert_redirected_to new_session_url

    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)
    assert_response :success
    assert_select "nav.content-tabs a", text: "Narrative order", count: 0
  end

  test "the signed-in tab is on every Story workspace page" do
    {
      "Sections" => universe_story_sections_url(universe_slug: @universe.slug, story_id: @story),
      "Plots" => universe_story_plots_url(universe_slug: @universe.slug, story_id: @story),
      "Scenes" => universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)
    }.each_value do |url|
      get url
      assert_response :success
      assert_select "nav.content-tabs a[href=?]", narrative_order_path, text: "Narrative order"
    end
  end

  test "the comparison is Spanish when the reader's language is Spanish" do
    patch settings_url, params: { locale: "es" }

    get narrative_order_url

    assert_response :success
    assert_select "h1", text: "Orden narrativo"
    assert_select "nav.content-tabs a.active", text: "Orden narrativo"
    assert_select "h2", text: "Cómo leer la comparación"
    assert_select "dt", text: /Primera de este tramo/
    assert_select "ol.list-group", text: /Sin suceso vinculado/
  end
end
