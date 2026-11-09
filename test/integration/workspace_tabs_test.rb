require "test_helper"

class WorkspaceTabsTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  test "character workspace keeps characters and relations together" do
    assert_workspace_tabs [
      [ "Characters", universe_characters_path(universe_slug: @universe.slug) ],
      [ "Relations", universe_relations_path(universe_slug: @universe.slug) ]
    ], sidebar_label: "Characters"
    assert_menu_tab universe_characters_path(universe_slug: @universe.slug),
      "Character tag one",
      universe_character_tag_path(universe_slug: @universe.slug, id: character_tags(:character_tag_one), from: "workspace")
  end

  test "item workspace keeps items and ownerships together" do
    assert_workspace_tabs [
      [ "Items", universe_items_path(universe_slug: @universe.slug) ],
      [ "Ownerships", universe_ownerships_path(universe_slug: @universe.slug) ]
    ], sidebar_label: "Items"
    assert_menu_tab universe_items_path(universe_slug: @universe.slug),
      "Item tag one",
      universe_item_tag_path(universe_slug: @universe.slug, id: item_tags(:item_tag_one), from: "workspace")
  end

  test "location workspace keeps locations, routes, and map together" do
    assert_workspace_tabs [
      [ "Locations", universe_locations_path(universe_slug: @universe.slug) ],
      [ "Routes", universe_routes_path(universe_slug: @universe.slug) ],
      [ "Map", universe_map_path(universe_slug: @universe.slug) ]
    ], sidebar_label: "Locations"
    assert_menu_tab universe_locations_path(universe_slug: @universe.slug),
      "Location tag one",
      universe_location_tag_path(universe_slug: @universe.slug, id: location_tags(:location_tag_one), from: "workspace")
  end

  test "event workspace has one record tab" do
    assert_workspace_tabs [
      [ "Events", universe_events_path(universe_slug: @universe.slug) ]
    ], sidebar_label: "Events"
    assert_menu_tab universe_events_path(universe_slug: @universe.slug),
      "Event tag one",
      universe_event_tag_path(universe_slug: @universe.slug, id: event_tags(:event_tag_one), from: "workspace")
  end

  test "the Scene workspace keeps the Scenes list and board together" do
    assert_workspace_tabs [
      [ "Scenes", universe_story_scenes_path(universe_slug: @universe.slug, story_id: @story), "Scenes" ],
      [ "Scene board", universe_story_scene_board_path(universe_slug: @universe.slug, story_id: @story), "Scenes" ]
    ]
  end

  test "Sections, Plots, and the Story analytics pages have no Scene tab strip" do
    {
      universe_story_sections_path(universe_slug: @universe.slug, story_id: @story) => "Sections",
      universe_story_plots_path(universe_slug: @universe.slug, story_id: @story) => "Plots"
    }.each do |path, label|
      get path

      assert_response :success
      assert_select "main nav.content-tabs", 0
      assert_select "aside.workspace-sidebar a.sidebar-link.active[aria-current='page'] .sidebar-link-label",
        text: label
    end

    get universe_story_narrative_order_path(universe_slug: @universe.slug, story_id: @story)
    assert_response :success
    assert_select "main nav.content-tabs", 0
    assert_select "aside.workspace-sidebar section[aria-labelledby='story-analytics-title'] a.sidebar-link.active .sidebar-link-label",
      text: "Narrative order"

    get universe_story_appearances_path(universe_slug: @universe.slug, story_id: @story)
    assert_response :success
    assert_select "main nav.content-tabs", 0
    assert_select "aside.workspace-sidebar section[aria-labelledby='story-analytics-title'] a.sidebar-link.active .sidebar-link-label",
      text: "Appearances"

    get universe_story_scene_matrix_path(universe_slug: @universe.slug, story_id: @story)
    assert_response :success
    assert_select "main nav.content-tabs", 0
    assert_select "aside.workspace-sidebar section[aria-labelledby='story-analytics-title'] a.sidebar-link.active .sidebar-link-label",
      text: "Scene matrix"
  end

  test "tags workspace has universe and story selectors" do
    get universe_tags_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "main h1", text: "Tags"
    assert_select "main nav[aria-label='Tag scope'] a", 2
    assert_select "main nav[aria-label='Tag scope'] a.active[aria-current='page']", text: "Universe Tags"
    assert_select "main nav[aria-label='Universe tag workspace'] a", 7
    assert_select "main nav[aria-label='Universe tag workspace'] a.active[aria-current='page']", text: "Character tags"
    assert_select "main nav[aria-label='Universe tag workspace'] a", text: "Relation tags"
    assert_select "main nav[aria-label='Universe tag workspace'] a", text: "Faction tags"
    assert_select "main nav[aria-label='Universe tag workspace'] a", text: "Location tags"
    assert_select "main nav[aria-label='Universe tag workspace'] a", text: "Event tags"
    assert_select "main nav[aria-label='Universe tag workspace'] a", text: "Item tags"
    assert_select "main nav[aria-label='Universe tag workspace'] a", text: "Ownership tags"
    assert_select "aside.right-sidebar a.sidebar-link.active .sidebar-link-label", text: "Tags"

    get universe_story_url(universe_slug: @universe.slug, id: @story)
    get universe_tags_url(universe_slug: @universe.slug, scope: "story")

    assert_response :success
    assert_select "main nav[aria-label='Tag scope'] a.active[aria-current='page']", text: "Story Tags"
    assert_select "main nav[aria-label='Story tag workspace'] a", 2
    assert_select "main nav[aria-label='Story tag workspace'] a.active[aria-current='page']", text: "Section tags"
    assert_select "main h1", text: "Tags"
  end

  test "story tag selection is scoped to the selected story" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)
    get universe_tags_url(universe_slug: @universe.slug, scope: "story", taxonomy: "section")

    assert_response :success
    assert_select "main h1", text: "Tags"
    assert_includes response.body, @story.section_tags.first.name
    assert_select "aside.right-sidebar a.sidebar-link.active .sidebar-link-label", text: "Tags"
  end

  test "every universe taxonomy selector has a working editor" do
    %w[character relation location event item ownership].each do |taxonomy|
      get universe_tags_url(universe_slug: @universe.slug, taxonomy: taxonomy)

      assert_response :success
      assert_select "main nav[aria-label='Universe tag workspace'] a.active[aria-current='page']",
        text: taxonomy.capitalize + " tags"
      assert_select "main .taxonomy-tree"
    end
  end

  test "story tags prompt for a story when none is selected" do
    get universe_tags_url(universe_slug: @universe.slug, scope: "story")

    assert_response :success
    assert_select "main nav[aria-label='Tag scope'] a.active[aria-current='page']", text: "Story Tags"
    assert_select "main nav[aria-label='Story tag workspace'] a", 2
    assert_select "main .empty-state", text: /Select a story/
  end

  private
    # A `show_in_menu` tag is pinned to the workspace tab strip. It links to the
    # tag's own details page rather than a same-workspace page, so it is asserted
    # on the index alone instead of through `assert_workspace_tabs`.
    def assert_menu_tab(index_path, label, path)
      get index_path

      assert_response :success
      assert_select "main nav.content-tabs a[href=?]", path, text: label
    end

    # Each tab is [label, path] or [label, path, sidebar_label] when the workspace
    # sidebar highlights a different entry than the tab label. The record tabs are
    # the first tabs on the strip, in order; a `show_in_menu` tag may add more
    # tabs after them on the index page.
    def assert_workspace_tabs(tabs, sidebar_label: nil)
      tabs.each do |tab|
        active_label, path, tab_sidebar_label = tab
        tab_sidebar_label ||= sidebar_label || active_label
        get path

        assert_response :success
        rendered = css_select("main nav.content-tabs a").map { |link| link.text.strip }
        assert_equal tabs.map(&:first), rendered.first(tabs.size)
        tabs.each do |label, tab_path|
          assert_select "main nav.content-tabs a[href=?]", tab_path, text: label
        end
        assert_select "main nav.content-tabs a.active[aria-current='page']", text: active_label
        assert_select "aside.workspace-sidebar a.sidebar-link.active[aria-current='page'] .sidebar-link-label",
          text: tab_sidebar_label
      end
    end
end
