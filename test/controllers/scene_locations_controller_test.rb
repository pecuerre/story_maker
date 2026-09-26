require "test_helper"

# The Locations tab is a real read page (guests and read-only members see it),
# while its mutations are JSON-only (ADR 0011). The tab is plural, so one scene
# holds several places, and it is the only workspace that has to name a linked
# record with its ancestor path.
class SceneLocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
    @path = universe_story_scene_scene_locations_path(universe_slug: @universe.slug,
      story_id: @story, scene_id: @scene)
    sign_in_as(users(:user_one))
  end

  def private_scene
    universe = Universe.create!(owner: users(:user_one), name: "Private places", slug: "private-places", private: true)
    story = Story.create!(universe: universe, name: "Private story")
    [ universe, story, story.scenes.create!(name: "Private scene") ]
  end

  def sign_in_read_only_member(universe)
    UniverseMembership.create!(universe: universe, user: users(:user_two), access_level: :read)
    sign_out
    sign_in_as(users(:user_two))
  end

  def listed_names
    css_select(".entity-list .entity-title").map { |title| title.text.squish }
  end

  # The page builds the linked rows and the whole universe's picker and paths, so
  # a per-row parent walk would make this a query per row. The page's own chrome
  # (session, universe, story, sidebar counts) is the same in both measurements, so
  # the difference between a short and a long row list is the whole point.
  test "the rows and the picker cost a fixed number of queries, not one per row" do
    get @path
    assert_equal 2, listed_names.size
    with_two_rows = count_queries { get @path }

    5.times { |index| @universe.locations.create!(name: "Extra #{index}", position: 10 + index) }
    (2..6).each { |index| @scene.scene_locations.create!(location: @universe.locations.order(:id).to_a[index], role: "r#{index}") }
    get @path
    assert_equal 7, listed_names.size
    with_seven_rows = count_queries { get @path }

    assert_response :success
    # Five more rows, and the same number of queries: the links, their Locations,
    # the universe list, and the path index are each read once.
    assert_equal with_two_rows, with_seven_rows,
      "a query per row would add five: #{with_two_rows} then #{with_seven_rows}"
  end

  test "the tab lists every linked location with its role" do
    get @path

    assert_response :success
    assert_equal [ "Location one", "Location two" ], listed_names
    assert_includes response.body, "Role: setting"
    # A blank role is a real state, not a missing value.
    assert_includes response.body, "No role recorded"
  end

  test "a nested place is named with its ancestor path" do
    room = @universe.locations.create!(name: "Martha Room", position: 5, parent: locations(:location_one))
    @scene.scene_locations.create!(location: room, role: "waits in")

    get @path

    assert_response :success
    assert_includes listed_names, "Location one / Martha Room"
  end

  test "the picker offers every universe location, indented, and a duplicate is refused" do
    third = @universe.locations.create!(name: "Third")

    get @path

    assert_response :success
    # The blank prompt plus every universe location.
    assert_select "select[name='scene_location[location_id]'] option", count: 4
    assert_select "select[name='scene_location[location_id]'] option[value='']", text: "Choose a location"
    assert_select "select[name='scene_location[location_id]'] option[value=?]", third.id
    # A location already in the scene is not hidden, because a stale page or a
    # second window can submit one anyway; the model reports it as an error.
    assert_select "select[name='scene_location[location_id]'] option[value=?]", locations(:location_one).id
    assert_no_difference("SceneLocation.count") do
      post @path, params: { scene_location: { location_id: locations(:location_one).id } }, as: :json
    end
    assert_response :unprocessable_content
    assert_equal [ "is already in this scene" ], response.parsed_body["location_id"]
  end

  test "an empty scene says how a location can end up on the tab" do
    empty = @story.scenes.create!(name: "Empty scene")

    get universe_story_scene_scene_locations_path(universe_slug: @universe.slug, story_id: @story, scene_id: empty)

    assert_response :success
    assert_select ".empty-title", text: "No locations in this scene yet"
    assert_select ".empty-description", text: /shared by every story/
  end

  test "creates a presence link with an optional role" do
    new_location = @universe.locations.create!(name: "Third")

    assert_difference("SceneLocation.count", 1) do
      post @path, params: { scene_location: { location_id: new_location.id, role: "arrives at" } }, as: :json
    end

    assert_response :created
    link = @scene.scene_locations.order(:id).last
    assert_equal new_location, link.location
    assert_equal "arrives at", link.role
    assert_equal new_location.id, response.parsed_body["location_id"]
  end

  test "a blank role is stored as no role" do
    new_location = @universe.locations.create!(name: "Fourth")

    post @path, params: { scene_location: { location_id: new_location.id, role: "" } }, as: :json

    assert_response :created
    assert_nil @scene.scene_locations.order(:id).last.role
  end

  test "a duplicate link is an ordinary 422 even when a stale page submits one" do
    assert_no_difference("SceneLocation.count") do
      post @path, params: { scene_location: { location_id: locations(:location_one).id } }, as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "is already in this scene" ], response.parsed_body["location_id"]
  end

  test "an update can repoint a link at another location in the same universe" do
    link = scene_locations(:scene_location_one)
    original = link.location

    patch universe_story_scene_scene_location_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link),
      params: { scene_location: { location_id: original.id, role: "the setting" } }, as: :json

    assert_response :success
    assert_equal original, link.reload.location
    assert_equal "the setting", link.role
  end

  test "repointing a link at a location that is already in the scene is a 422" do
    link = scene_locations(:scene_location_one)

    patch universe_story_scene_scene_location_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_location: { location_id: locations(:location_two).id } }, as: :json

    assert_response :unprocessable_content
    assert_equal [ "is already in this scene" ], response.parsed_body["location_id"]
    assert_equal locations(:location_one), link.reload.location
  end

  test "a role-only update leaves the location alone" do
    link = scene_locations(:scene_location_one)

    patch universe_story_scene_scene_location_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_location: { role: "left behind" } }, as: :json

    assert_response :success
    assert_equal locations(:location_one), link.reload.location
    assert_equal "left behind", link.role
  end

  test "a blank location on an update means keep the current one" do
    link = scene_locations(:scene_location_one)

    patch universe_story_scene_scene_location_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_location: { location_id: "", role: "stays" } }, as: :json

    assert_response :success
    assert_equal locations(:location_one), link.reload.location
    assert_equal "stays", link.role
  end

  test "a location from another universe is not found" do
    outsider = universes(:universe_two).locations.create!(name: "Outsider")

    assert_no_difference("SceneLocation.count") do
      post @path, params: { scene_location: { location_id: outsider.id } }, as: :json
    end

    assert_response :not_found
  end

  test "an unknown location is not found rather than a foreign key error" do
    assert_no_difference("SceneLocation.count") do
      post @path, params: { scene_location: { location_id: 0 } }, as: :json
    end

    assert_response :not_found
  end

  test "a missing location is a bad request" do
    assert_no_difference("SceneLocation.count") do
      post @path, params: { scene_location: { role: "setting" } }, as: :json
    end

    assert_response :bad_request
  end

  test "an update with no editable field is a bad request" do
    assert_no_difference("SceneLocation.count") do
      patch universe_story_scene_scene_location_path(universe_slug: @universe.slug, story_id: @story,
        scene_id: @scene, id: scene_locations(:scene_location_one)), params: { scene_location: {} }, as: :json
    end

    assert_response :bad_request
  end

  test "edits the role and reports the new value" do
    link = scene_locations(:scene_location_one)

    patch universe_story_scene_scene_location_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_location: { role: "left behind" } }, as: :json

    assert_response :success
    assert_equal "left behind", link.reload.role
    assert_equal "left behind", response.parsed_body["role"]
  end

  test "clears a role by sending a blank one" do
    link = scene_locations(:scene_location_one)

    patch universe_story_scene_scene_location_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_location: { role: "  " } }, as: :json

    assert_response :success
    assert_nil link.reload.role
  end

  test "removing a link keeps the location and every other scene that uses it" do
    link = scene_locations(:scene_location_one)
    location = link.location

    assert_difference("SceneLocation.count", -1) do
      delete universe_story_scene_scene_location_path(universe_slug: @universe.slug, story_id: @story,
        scene_id: @scene, id: link), as: :json
    end

    assert_response :no_content
    assert Location.exists?(location.id)
    # The same place is linked into a second scene, which is the shared-universe
    # point: withdrawing one Scene's claim never touches another's.
    assert_equal [ scene_locations(:scene_location_three).id ], location.scene_locations.pluck(:id)
  end

  test "an html mutation is refused before anything is written" do
    assert_no_difference("SceneLocation.count") do
      post @path, params: { scene_location: { location_id: locations(:location_one).id } }
    end
    assert_response :not_acceptable

    link = scene_locations(:scene_location_one)
    patch universe_story_scene_scene_location_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_location: { role: "html" } }
    assert_response :not_acceptable

    assert_no_difference("SceneLocation.count") do
      delete universe_story_scene_scene_location_path(universe_slug: @universe.slug, story_id: @story,
        scene_id: @scene, id: link)
    end
    assert_response :not_acceptable

    assert_equal "setting", link.reload.role
  end

  test "guests can read the tab and are sent to sign in to change it" do
    sign_out

    get @path

    assert_response :success
    assert_equal [ "Location one", "Location two" ], listed_names
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select "button[data-action='modal-form#destroy']", count: 0
    assert_select "[data-modal-form-target='errors']", count: 0

    assert_no_difference("SceneLocation.count") do
      post @path, params: { scene_location: { location_id: locations(:location_one).id } }, as: :json
    end
    assert_redirected_to new_session_url
  end

  test "read-only members see the tab without any control" do
    universe, story, scene = private_scene
    scene.scene_locations.create!(location: universe.locations.create!(name: "Reader's house"), role: "setting")
    sign_in_read_only_member(universe)

    get universe_story_scene_scene_locations_path(universe_slug: universe.slug, story_id: story, scene_id: scene)

    assert_response :success
    assert_equal [ "Reader's house" ], listed_names
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select "button[data-action='modal-form#destroy']", count: 0
    assert_select "[data-controller='modal-form']", count: 0

    link = scene.scene_locations.first
    patch universe_story_scene_scene_location_path(universe_slug: universe.slug, story_id: story,
      scene_id: scene, id: link), params: { scene_location: { role: "hijacked" } }, as: :json
    assert_response :forbidden

    assert_no_difference("SceneLocation.count") do
      delete universe_story_scene_scene_location_path(universe_slug: universe.slug, story_id: story,
        scene_id: scene, id: link), as: :json
    end
    assert_response :forbidden

    assert_equal "setting", link.reload.role
  end

  test "a private universe tab stays hidden from non-members and guests" do
    universe, story, scene = private_scene

    sign_in_as(users(:user_two))
    get universe_story_scene_scene_locations_path(universe_slug: universe.slug, story_id: story, scene_id: scene)
    assert_response :not_found

    sign_out
    get universe_story_scene_scene_locations_path(universe_slug: universe.slug, story_id: story, scene_id: scene)
    assert_response :not_found
  end

  test "a link cannot be managed through another scene, story, or universe" do
    link = scene_locations(:scene_location_one)

    patch universe_story_scene_scene_location_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: scenes(:scene_three), id: link), params: { scene_location: { role: "hijacked" } }, as: :json
    assert_response :not_found

    patch universe_story_scene_scene_location_path(universe_slug: @universe.slug, story_id: stories(:story_alt),
      scene_id: scenes(:scene_alt), id: link), params: { scene_location: { role: "hijacked" } }, as: :json
    assert_response :not_found

    delete universe_story_scene_scene_location_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: scenes(:scene_three), id: link), as: :json
    assert_response :not_found

    assert_equal "setting", link.reload.role
  end

  private

    def count_queries(&block)
      count = 0
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        count += 1 unless payload[:name] == "SCHEMA"
      end
      block.call
      count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
end
