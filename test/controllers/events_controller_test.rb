require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @story = stories(:story_one)
    @event = events(:event_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get story_events_url(story_slug: @story.slug)

    assert_response :success
    assert_includes response.body, "Events"
    assert_includes response.body, @event.title
  end

  test "should create event with only a title as json" do
    assert_difference("Event.count") do
      post story_events_url(story_slug: @story.slug),
        params: { event: { title: "New event" } },
        as: :json
    end

    assert_response :created
    assert_equal "New event", response.parsed_body["title"]
  end

  test "should not create an event with no identifying attribute" do
    assert_no_difference("Event.count") do
      post story_events_url(story_slug: @story.slug),
        params: { event: { description: "Just a description" } },
        as: :json
    end

    assert_response :unprocessable_content
  end

  test "should update event details as json" do
    patch story_event_url(story_slug: @story.slug, id: @event),
      params: { event: { title: "Renamed" } },
      as: :json

    assert_response :success
    assert_equal "Renamed", @event.reload.title
  end

  test "should destroy event" do
    assert_difference("Event.count", -1) do
      delete story_event_url(story_slug: @story.slug, id: @event)
    end

    assert_response :no_content
  end
end
