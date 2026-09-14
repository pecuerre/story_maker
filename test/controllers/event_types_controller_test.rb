require "test_helper"

class EventTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event_type = event_types(:event_type_one)
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get universe_event_types_url(universe_slug: @universe.slug)
    assert_response :success
    assert_select "a.nav-link.active", text: "Event Types(2)"
  end

  test "should create event_type as json for inline editing" do
    assert_difference("EventType.count") do
      post universe_event_types_url(universe_slug: @universe.slug),
        params: { event_type: { name: "Inline type", parent_id: @event_type.id } },
        as: :json
    end

    assert_response :created
    assert_equal "Inline type", response.parsed_body["name"]
    assert_equal @event_type.id, response.parsed_body["parent_id"]
  end

  test "should update event_type as json for inline editing" do
    patch universe_event_type_url(universe_slug: @universe.slug, id: @event_type),
      params: { event_type: { name: "Inline rename", description: "Inline description", bgcolor: "#00ff00" } },
      as: :json

    assert_response :success
    assert_equal "Inline rename", response.parsed_body["name"]
    assert_equal "Inline description", response.parsed_body["description"]
    assert_equal "#00ff00", response.parsed_body["bgcolor"]
  end

  test "should destroy event_type as json" do
    assert_difference("EventType.count", -1) do
      delete universe_event_type_url(universe_slug: @universe.slug, id: @event_type), as: :json
    end

    assert_response :no_content
  end
end
