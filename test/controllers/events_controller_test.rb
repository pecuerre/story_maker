require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @event = events(:event_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get universe_events_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Events"
    assert_includes response.body, @event.title
  end

  test "should create event with only a title as json" do
    assert_difference("Event.count") do
      post universe_events_url(universe_slug: @universe.slug),
        params: { event: { title: "New event" } },
        as: :json
    end

    assert_response :created
    assert_equal "New event", response.parsed_body["title"]
  end

  test "should create a tagged event as json" do
    event_tag = event_tags(:event_tag_two)

    assert_difference("Event.count") do
      post universe_events_url(universe_slug: @universe.slug),
        params: { event: { title: "Tagged event", event_tag_ids: [ event_tag.id ] } },
        as: :json
    end

    assert_response :created
    assert_equal [ event_tag.id ], response.parsed_body["event_tag_ids"]
  end

  test "should not create an event with no identifying attribute" do
    assert_no_difference("Event.count") do
      post universe_events_url(universe_slug: @universe.slug),
        params: { event: { description: "Just a description" } },
        as: :json
    end

    assert_response :unprocessable_content
  end

  test "should reject event tags from another universe" do
    foreign_tag = event_tags(:event_tag_three)
    join_count = -> { ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM events_event_tags") }

    assert_no_difference([ "Event.count", join_count ]) do
      post universe_events_url(universe_slug: @universe.slug),
        params: { event: { title: "Mis-scoped event", event_tag_ids: [ foreign_tag.id ] } },
        as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "must belong to the same universe" ], response.parsed_body["event_tags"]
  end

  test "should update event details as json" do
    patch universe_event_url(universe_slug: @universe.slug, id: @event),
      params: { event: { title: "Renamed" } },
      as: :json

    assert_response :success
    assert_equal "Renamed", @event.reload.title
    assert_equal "Renamed", @event.name
    assert_equal "renamed", @event.slug
  end

  test "should destroy event" do
    assert_difference("Event.count", -1) do
      delete universe_event_url(universe_slug: @universe.slug, id: @event)
    end

    assert_response :no_content
  end

  test "should destroy an event referenced by another event" do
    reference = Event.create!(universe: @universe, title: "Reference", before_event: @event)

    assert_difference("Event.count", -1) do
      delete universe_event_url(universe_slug: @universe.slug, id: @event)
    end

    assert_response :no_content
    assert_nil reference.reload.before_event
  end

  test "should destroy an event referenced by a scene without deleting the scene" do
    scene = scenes(:scene_one)
    assert_equal @event, scene.event

    assert_difference("Event.count", -1) do
      assert_no_difference("Scene.count") do
        delete universe_event_url(universe_slug: @universe.slug, id: @event)
      end
    end

    assert_nil scene.reload.event
    assert_equal stories(:story_one), scene.story
  end

  test "the event delete confirmation states that scenes remain" do
    get universe_events_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "form[action=?] [data-turbo-confirm=?]",
      universe_event_path(universe_slug: @universe.slug, id: @event),
      "Delete “#{@event.display_string}”? Its child events, tag assignments, and any temporal " \
      "referrers that would become unidentifiable will be permanently removed; other temporal " \
      "references and Scene links will be cleared. Scenes will remain."
  end
end
