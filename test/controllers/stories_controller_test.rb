require "test_helper"

class StoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  test "should get index listing only this universe's stories" do
    get universe_stories_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Story One"
    assert_includes response.body, "Spin-off"
    assert_not_includes response.body, "Story Two"
  end

  test "should get new story" do
    get new_universe_story_url(universe_slug: @universe.slug)

    assert_response :success
  end

  test "should create story" do
    assert_difference("Story.count") do
      post universe_stories_url(universe_slug: @universe.slug),
        params: { story: { name: "House of the Dragon", description: "A new story" } }
    end

    story = Story.order(:id).last
    assert_redirected_to universe_story_url(universe_slug: @universe.slug, id: story)
    assert_equal @universe, story.universe
    assert_equal "house-of-the-dragon", story.slug
  end

  test "should not create story without a name" do
    assert_no_difference("Story.count") do
      post universe_stories_url(universe_slug: @universe.slug), params: { story: { name: "" } }
    end

    assert_response :unprocessable_content
  end

  test "should update story" do
    story = stories(:story_alt)

    patch universe_story_url(universe_slug: @universe.slug, id: story),
      params: { story: { name: "Renamed spin-off", description: "Updated" } }

    assert_redirected_to universe_story_url(universe_slug: @universe.slug, id: story)
    story.reload
    assert_equal [ "Renamed spin-off", "Updated" ], [ story.name, story.description ]
  end

  test "should destroy story and its sections" do
    story = stories(:story_one)

    assert_difference("Story.count", -1) do
      assert_difference("Section.count", -2) do
        delete universe_story_url(universe_slug: @universe.slug, id: story)
      end
    end

    assert_redirected_to universe_stories_url(universe_slug: @universe.slug)
  end

  test "cannot reach a story belonging to another universe" do
    get universe_story_url(universe_slug: @universe.slug, id: stories(:story_two))

    assert_response :not_found
  end
end
