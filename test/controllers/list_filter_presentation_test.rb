require "test_helper"

# Every in-list filter shares one search-area shape: the search stays in the
# first row and its narrowing controls sit behind a closed **Advanced filters**
# disclosure. Each workspace's own test proves its keys and its query; this test
# proves the shared shape reached every workspace, that the disclosure starts
# closed, and that a closed disclosure still reports what it is applying.
class ListFilterPresentationTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  test "every flat list keeps its search outside one closed advanced disclosure" do
    lists = {
      universe_story_scenes_path(universe_slug: @universe.slug, story_id: @story) => ".scene-filter",
      universe_characters_path(universe_slug: @universe.slug) => ".character-filter",
      universe_items_path(universe_slug: @universe.slug) => ".item-filter",
      universe_events_path(universe_slug: @universe.slug) => ".event-filter",
      universe_relations_path(universe_slug: @universe.slug) => ".relation-filter",
      universe_ownerships_path(universe_slug: @universe.slug) => ".ownership-filter",
      universe_canon_rules_path(universe_slug: @universe.slug) => ".canon-rule-filter"
    }

    lists.each do |path, selector|
      get path
      assert_response :success, path

      assert_select "#{selector} input[name=q]", count: 1
      assert_select "#{selector} details.list-filter-advanced", count: 1
      assert_select "#{selector} details.list-filter-advanced:not([open])", count: 1
      assert_select "#{selector} details.list-filter-advanced > summary",
        text: /#{I18n.t("shared.list_filter.advanced")}/
      assert_select "#{selector} details.list-filter-advanced input[name=q]", count: 0
      assert_select "#{selector} details.list-filter-advanced > summary .badge", count: 0
    end
  end

  test "a tree with a tag filter uses the disclosure, and a tree without one renders none" do
    get universe_locations_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".taxonomy-tree-filter details.list-filter-advanced", count: 1
    assert_select ".taxonomy-tree-filter details.list-filter-advanced select[name=location_tag_id]",
      count: 1
    assert_select ".taxonomy-tree-filter details.list-filter-advanced input[name=q]", count: 0

    get universe_character_tags_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".taxonomy-tree-filter input[name=q]", count: 1
    assert_select ".taxonomy-tree-filter details.list-filter-advanced", count: 0
  end

  test "a closed disclosure still carries its filter and reports how many are active" do
    get universe_characters_path(
      universe_slug: @universe.slug,
      character_tag_id: character_tags(:character_tag_two).id
    )

    assert_response :success
    assert_select ".character-filter details.list-filter-advanced:not([open])"
    assert_select ".character-filter details.list-filter-advanced > summary .badge",
      text: "1 active"
    assert_select ".character-filter", text: /Character tag: Character tag two/

    get universe_story_scenes_path(
      universe_slug: @universe.slug,
      story_id: @story,
      section_id: sections(:section_one).id,
      status: "final"
    )

    assert_response :success
    assert_select ".scene-filter details.list-filter-advanced > summary .badge",
      text: "2 active"
    assert_select ".scene-filter", text: /Section: Section one/
    assert_select ".scene-filter", text: /Status: Final/
  end
end
