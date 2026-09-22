require "test_helper"

class EventTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event_tag = event_tags(:event_tag_one)
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get universe_event_tags_url(universe_slug: @universe.slug)
    assert_response :success
    assert_select "h1", text: "Event Tags"
    assert_select "a.nav-link.active[href=?]", universe_event_tags_path(universe_slug: @universe.slug)
    assert_select ".taxonomy-node", 2
  end

  test "should create event_tag as json for inline editing" do
    assert_difference("EventTag.count") do
      post universe_event_tags_url(universe_slug: @universe.slug),
        params: { event_tag: { name: "Inline tag", parent_id: @event_tag.id } },
        as: :json
    end

    assert_response :created
    assert_equal "Inline tag", response.parsed_body["name"]
    assert_equal @event_tag.id, response.parsed_body["parent_id"]
  end

  test "should update event_tag as json for inline editing" do
    patch universe_event_tag_url(universe_slug: @universe.slug, id: @event_tag),
      params: { event_tag: { name: "Inline rename", description: "Inline description", bgcolor: "#00ff00" } },
      as: :json

    assert_response :success
    assert_equal "Inline rename", response.parsed_body["name"]
    assert_equal "Inline description", response.parsed_body["description"]
    assert_equal "#00ff00", response.parsed_body["bgcolor"]
  end

  test "should destroy event_tag as json" do
    assert_difference("EventTag.count", -1) do
      delete universe_event_tag_url(universe_slug: @universe.slug, id: @event_tag), as: :json
    end

    assert_response :no_content
  end
end
