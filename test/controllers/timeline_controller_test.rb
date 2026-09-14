require "test_helper"

class TimelineControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  test "should get timeline" do
    get universe_timeline_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Timeline"
  end
end
