require "test_helper"

# The Events tab is a real read page (guests and read-only members see it), while
# its mutations are JSON-only under the shared modal contract. A Scene may depict
# several Events; each link carries the author's own free-text role and an order
# the Move controls maintain.
class SceneEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
    @path = universe_story_scene_scene_events_path(universe_slug: @universe.slug,
      story_id: @story, scene_id: @scene)
    sign_in_as(users(:user_one))
  end

  def private_scene
    universe = Universe.create!(owner: users(:user_one), name: "Private events", slug: "private-events", private: true)
    story = Story.create!(universe: universe, name: "Private story")
    [ universe, story, story.scenes.create!(name: "Private scene") ]
  end

  def sign_in_read_only_member(universe)
    UniverseMembership.create!(universe: universe, user: users(:user_two), access_level: :read)
    sign_out
    sign_in_as(users(:user_two))
  end

  def listed_titles
    css_select(".entity-list .entity-title").map { |title| title.text.squish }
  end

  test "the tab lists the scene's events in the scene's own order with their roles" do
    get @path

    assert_response :success
    assert_equal [ events(:event_one).display_label ], listed_titles
    assert_includes response.body, "No role recorded"
    assert_select ".entity-description", text: /No role recorded/
  end

  test "the tab lists several events in their own order and with their own roles" do
    second = @scene.scene_events.create!(event: events(:event_two), position: 1, role: "climax")
    @scene.scene_events.find_by!(event: events(:event_one)).update!(role: "opening")

    get @path

    assert_response :success
    assert_equal [ events(:event_one).display_label, second.event.display_label ], listed_titles
    assert_includes response.body, "opening"
    assert_includes response.body, "climax"
  end

  test "an empty scene says how an event can end up on the tab" do
    empty = @story.scenes.create!(name: "Empty scene", position: 3)

    get universe_story_scene_scene_events_path(universe_slug: @universe.slug, story_id: @story, scene_id: empty)

    assert_response :success
    assert_select ".empty-title", text: "No events in this scene yet"
    assert_select ".empty-description", text: /A scene may depict any number of events/
  end

  test "the picker offers every universe event and a duplicate is refused" do
    get @path

    assert_response :success
    assert_select "select[name='scene_event[event_id]'] option", count: 3
    assert_select "select[name='scene_event[event_id]'] option[value='']", text: "Choose an event"
    assert_select "select[name='scene_event[event_id]'] option[value=?]", events(:event_two).id
    # An event already linked to the scene is not hidden, because a stale page or a
    # second window can submit one anyway; the model reports it as an error.
    assert_select "select[name='scene_event[event_id]'] option[value=?]", events(:event_one).id
    assert_no_difference("SceneEvent.count") do
      post @path, params: { scene_event: { event_id: events(:event_one).id } }, as: :json
    end
    assert_response :unprocessable_content
    assert_equal [ I18n.t("scenes.events.already_linked") ], response.parsed_body["event_id"]
  end

  test "creates a link with an optional role, appended to the scene's order" do
    assert_difference("SceneEvent.count", 1) do
      post @path, params: { scene_event: { event_id: events(:event_two).id, role: "climax" } }, as: :json
    end

    assert_response :created
    link = @scene.scene_events.order(:id).last
    assert_equal events(:event_two), link.event
    assert_equal "climax", link.role
    assert_equal 1, link.position
    assert_equal events(:event_two).display_label, response.parsed_body["event_label"]
  end

  test "a blank role is stored as no role" do
    post @path, params: { scene_event: { event_id: events(:event_two).id, role: "" } }, as: :json

    assert_response :created
    assert_nil @scene.scene_events.order(:id).last.role
  end

  test "an update can repoint a link, change only its role, or keep a blank event" do
    link = scene_events(:scene_event_one)

    patch universe_story_scene_scene_event_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_event: { event_id: events(:event_two).id } }, as: :json

    assert_response :success
    assert_equal events(:event_two), link.reload.event
    assert_nil link.role

    patch universe_story_scene_scene_event_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_event: { event_id: "", role: "climax" } }, as: :json

    assert_response :success
    assert_equal events(:event_two), link.reload.event
    assert_equal "climax", link.role
  end

  test "repointing a link at an event the scene already depicts is a 422" do
    link = scene_events(:scene_event_one)
    @scene.scene_events.create!(event: events(:event_two), position: 1)

    patch universe_story_scene_scene_event_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_event: { event_id: events(:event_two).id } }, as: :json

    assert_response :unprocessable_content
    assert_equal events(:event_one), link.reload.event
  end

  test "an update with no editable field is a bad request" do
    link = scene_events(:scene_event_one)

    patch universe_story_scene_scene_event_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_event: {} }, as: :json

    assert_response :bad_request
  end

  test "an event from another universe is not found" do
    assert_no_difference("SceneEvent.count") do
      post @path, params: { scene_event: { event_id: events(:event_other_universe).id } }, as: :json
    end

    assert_response :not_found
  end

  test "an unknown event is not found and a missing one is a bad request" do
    assert_no_difference("SceneEvent.count") do
      post @path, params: { scene_event: { event_id: 0 } }, as: :json
    end
    assert_response :not_found

    assert_no_difference("SceneEvent.count") do
      post @path, params: { scene_event: { role: "climax" } }, as: :json
    end
    assert_response :bad_request
  end

  test "move up and move down reorder the scene's events" do
    second = @scene.scene_events.create!(event: events(:event_two), position: 1)
    first = scene_events(:scene_event_one)

    patch move_universe_story_scene_scene_event_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: second, direction: "up"), as: :json

    assert_response :success
    assert_equal [ second, first ], @scene.scene_events.reorder(:position, :id).to_a
    assert_equal 0, second.reload.position
    assert_equal 1, first.reload.position

    patch move_universe_story_scene_scene_event_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: second, direction: "down"), as: :json

    assert_response :success
    assert_equal [ first, second ], @scene.scene_events.reorder(:position, :id).to_a
  end

  test "move at a sequence boundary stays put and an unknown direction is a bad request" do
    link = scene_events(:scene_event_one)

    patch move_universe_story_scene_scene_event_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link, direction: "up"), as: :json

    assert_response :success
    assert_equal 0, link.reload.position

    patch move_universe_story_scene_scene_event_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link, direction: "sideways"), as: :json

    assert_response :bad_request
  end

  test "removing a link keeps the event and the scene" do
    link = scene_events(:scene_event_one)

    assert_difference("SceneEvent.count", -1) do
      delete universe_story_scene_scene_event_path(universe_slug: @universe.slug, story_id: @story,
        scene_id: @scene, id: link), as: :json
    end

    assert_response :no_content
    assert Event.exists?(link.event_id)
    assert Scene.exists?(link.scene_id)
    assert_predicate SceneEvent.with_deleted.find(link.id), :deleted?
  end

  test "an html mutation is refused before anything is written" do
    assert_no_difference("SceneEvent.count") do
      post @path, params: { scene_event: { event_id: events(:event_two).id } }
    end
    assert_response :not_acceptable

    link = scene_events(:scene_event_one)
    patch universe_story_scene_scene_event_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_event: { role: "html" } }
    assert_response :not_acceptable

    delete universe_story_scene_scene_event_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link)
    assert_response :not_acceptable
    assert_nil link.reload.role
  end

  test "guests can read the tab and are sent to sign in to change it" do
    sign_out

    get @path

    assert_response :success
    assert_equal [ events(:event_one).display_label ], listed_titles
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select "button[data-action='modal-form#destroy']", count: 0

    assert_no_difference("SceneEvent.count") do
      post @path, params: { scene_event: { event_id: events(:event_two).id } }, as: :json
    end
    assert_redirected_to new_session_url
  end

  test "read-only members see the tab without any control" do
    universe, story, scene = private_scene
    event = universe.events.create!(title: "A private event")
    scene.scene_events.create!(event: event, role: "opening")
    sign_in_read_only_member(universe)

    get universe_story_scene_scene_events_path(universe_slug: universe.slug, story_id: story, scene_id: scene)

    assert_response :success
    assert_equal [ event.display_label ], listed_titles
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select "[data-controller='modal-form']", count: 0

    link = scene.scene_events.first
    patch universe_story_scene_scene_event_path(universe_slug: universe.slug, story_id: story,
      scene_id: scene, id: link), params: { scene_event: { role: "hijacked" } }, as: :json
    assert_response :forbidden
    assert_equal "opening", link.reload.role
  end

  test "a private universe tab stays hidden from non-members and guests" do
    universe, story, scene = private_scene

    sign_in_as(users(:user_two))
    get universe_story_scene_scene_events_path(universe_slug: universe.slug, story_id: story, scene_id: scene)
    assert_response :not_found

    sign_out
    get universe_story_scene_scene_events_path(universe_slug: universe.slug, story_id: story, scene_id: scene)
    assert_response :not_found
  end
end
