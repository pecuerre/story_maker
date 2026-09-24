require "test_helper"

class CachedNavigationTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  teardown do
    Session.delete_all
    Rails.cache = @original_cache
  end

  test "sidebar count data is reused on later requests" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)
    assert_response :success

    assert_no_queries_match(/SELECT COUNT/i) do
      get universe_url(@universe)
    end
    assert_response :success
  end

  test "menu counts refresh after character requests change the data" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)
    assert_character_sidebar_count(2)

    post universe_characters_url(universe_slug: @universe.slug),
      params: { character: { name: "Navigation character" } },
      as: :json
    assert_response :created
    character_id = response.parsed_body["id"]

    get universe_story_url(universe_slug: @universe.slug, id: @story)
    assert_character_sidebar_count(3)

    delete universe_character_url(universe_slug: @universe.slug, id: character_id), as: :json
    assert_response :no_content

    get universe_story_url(universe_slug: @universe.slug, id: @story)
    assert_character_sidebar_count(2)
  end

  private
    def assert_character_sidebar_count(count)
      assert_select "aside.workspace-sidebar a.sidebar-link[href=?]",
        universe_characters_path(universe_slug: @universe.slug) do
        assert_select ".sidebar-count", text: count.to_s
      end
    end
end
