require "test_helper"

class WorkspaceTabsTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  test "character workspace tabs stay together across all four pages" do
    assert_workspace_tabs [
      [ "Characters", universe_characters_path(universe_slug: @universe.slug) ],
      [ "Character tags", universe_character_tags_path(universe_slug: @universe.slug) ],
      [ "Relations", universe_relations_path(universe_slug: @universe.slug) ],
      [ "Relation tags", universe_relation_tags_path(universe_slug: @universe.slug) ]
    ], sidebar_label: "Characters"
  end

  test "item workspace tabs stay together across all four pages" do
    assert_workspace_tabs [
      [ "Items", universe_items_path(universe_slug: @universe.slug) ],
      [ "Item tags", universe_item_tags_path(universe_slug: @universe.slug) ],
      [ "Ownerships", universe_ownerships_path(universe_slug: @universe.slug) ],
      [ "Ownership tags", universe_ownership_tags_path(universe_slug: @universe.slug) ]
    ], sidebar_label: "Items"
  end

  test "location tags share the location workspace" do
    assert_workspace_tabs [
      [ "Locations", universe_locations_path(universe_slug: @universe.slug) ],
      [ "Location tags", universe_location_tags_path(universe_slug: @universe.slug) ]
    ], sidebar_label: "Locations"
  end

  test "event tags share the event workspace" do
    assert_workspace_tabs [
      [ "Events", universe_events_path(universe_slug: @universe.slug) ],
      [ "Event tags", universe_event_tags_path(universe_slug: @universe.slug) ]
    ], sidebar_label: "Events"
  end

  test "section tags share the current story workspace" do
    assert_workspace_tabs [
      [ "Sections", universe_story_sections_path(universe_slug: @universe.slug, story_id: @story) ],
      [ "Section tags", universe_story_section_tags_path(universe_slug: @universe.slug, story_id: @story) ]
    ], sidebar_label: "Sections"
  end

  private
    def assert_workspace_tabs(tabs, sidebar_label:)
      tabs.each do |active_label, path|
        get path

        assert_response :success
        assert_select "main nav.content-tabs a", tabs.size
        assert_equal tabs.map(&:first),
          css_select("main nav.content-tabs a").map { |link| link.text.strip }
        tabs.each do |label, tab_path|
          assert_select "main nav.content-tabs a[href=?]", tab_path, text: label
        end
        assert_select "main nav.content-tabs a.active[aria-current='page']", text: active_label
        assert_select "aside.workspace-sidebar a.sidebar-link.active[aria-current='page'] .sidebar-link-label",
          text: sidebar_label
      end
    end
end
