require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  test "story tag workspace selects scene taxonomy and keeps section taxonomy available" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)
    get universe_tags_url(universe_slug: @universe.slug, scope: "story", taxonomy: "scene")

    assert_response :success
    assert_select "h1", text: "Tags"
    assert_select ".tag-scope-tabs a.active", text: "Story Tags"
    assert_select ".tag-taxonomy-tabs a.active", text: "Scene tags"
    assert_select ".tag-taxonomy-tabs a", text: "Section tags"
    assert_select ".taxonomy-node", text: /Scene tag one/
    assert_select "a[href=?]", universe_tags_path(universe_slug: @universe.slug, scope: "story", taxonomy: "section")
  end

  test "story tag workspace requires a selected story" do
    get universe_tags_url(universe_slug: @universe.slug, scope: "story", taxonomy: "scene")

    assert_response :success
    assert_select "h1", text: "Tags"
    assert_select ".empty-title", text: "Select a story"
    assert_includes response.body, "Story tags belong to an individual story"
  end

  test "a public-universe guest can inspect story taxonomy without controls" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)
    sign_out
    get universe_story_url(universe_slug: @universe.slug, id: @story)
    get universe_tags_url(universe_slug: @universe.slug, scope: "story", taxonomy: "scene")

    assert_response :success
    assert_select "h1", text: "Tags"
    assert_select ".taxonomy-node", text: /Scene tag one/
    assert_select "button", text: "Add scene tag", count: 0
  end
end
