require "test_helper"

class StoryInterchangeExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  def download_url(story: @story, universe: @universe)
    universe_story_export_interchange_url(universe_slug: universe.slug, story_id: story)
  end

  test "downloads one gzip archive of the universe" do
    get download_url

    assert_response :success
    assert_equal "application/gzip", response.media_type
    assert_match(/attachment; filename="one-story-interchange-\d{8}-\d{6}\.tar\.gz"/,
      response.headers["Content-Disposition"])
    assert_equal "no-store", response.headers["Cache-Control"]
    assert response.body.b.start_with?("\x1F\x8B".b)
  end

  test "a public universe is downloadable by a guest" do
    sign_out

    get download_url

    assert_response :success
    assert_equal "application/gzip", response.media_type
  end

  test "a private universe refuses a guest and a member may download" do
    private_universe = Universe.create!(owner: users(:user_two), name: "Private export",
      slug: "private-interchange", private: true)
    private_story = private_universe.stories.create!(name: "Private story")

    sign_out
    get download_url(story: private_story, universe: private_universe)
    assert_response :not_found

    sign_in_as(users(:user_one))
    get download_url(story: private_story, universe: private_universe)
    assert_response :not_found

    UniverseMembership.create!(universe: private_universe, user: users(:user_one), access_level: :read)
    get download_url(story: private_story, universe: private_universe)
    assert_response :success
  end

  test "another universe's story is a 404" do
    get download_url(story: stories(:story_two))

    assert_response :not_found
  end
end
