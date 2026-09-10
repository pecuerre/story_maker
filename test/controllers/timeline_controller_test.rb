require "test_helper"

class TimelineControllerTest < ActionDispatch::IntegrationTest
  setup do
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  test "should get timeline" do
    get story_timeline_url(story_slug: @story.slug)

    assert_response :success
    assert_includes response.body, "Timeline"
  end
end
