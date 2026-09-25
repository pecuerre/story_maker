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
  end

  test "item workspace keeps items and ownerships together" do
    assert_workspace_tabs [
      [ "Items", universe_items_path(universe_slug: @universe.slug) ],
      [ "Ownerships", universe_ownerships_path(universe_slug: @universe.slug) ]
    ], sidebar_label: "Items"
  end

  test "location workspace has one record tab" do
    assert_workspace_tabs [
      [ "Locations", universe_locations_path(universe_slug: @universe.slug) ]
    ], sidebar_label: "Locations"
  end

  test "event workspace has one record tab" do
    assert_workspace_tabs [
      [ "Events", universe_events_path(universe_slug: @universe.slug) ]
    ], sidebar_label: "Events"
  end

  test "story workspace keeps sections and scenes together" do
    assert_workspace_tabs [
      [ "Sections", universe_story_sections_path(universe_slug: @universe.slug, story_id: @story), "Sections" ],
      [ "Scenes", universe_story_scenes_path(universe_slug: @universe.slug, story_id: @story), "Scenes" ]
    ]
  end

  test "tags workspace has universe and story selectors" do
    get universe_tags_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "main h1", text: "Tags"
    assert_select "main nav[aria-label='Tag scope'] a", 2
    assert_select "main nav[aria-label='Tag scope'] a.active[aria-current='page']", text: "Universe Tags"
    assert_select "main nav[aria-label='Universe tag workspace'] a", 6
    assert_select "main nav[aria-label='Universe tag workspace'] a.active[aria-current='page']", text: "Character tags"
    assert_select "main nav[aria-label='Universe tag workspace'] a", text: "Relation tags"
    assert_select "main nav[aria-label='Universe tag workspace'] a", text: "Location tags"
    assert_select "main nav[aria-label='Universe tag workspace'] a", text: "Event tags"
    assert_select "main nav[aria-label='Universe tag workspace'] a", text: "Item tags"
    assert_select "main nav[aria-label='Universe tag workspace'] a", text: "Ownership tags"
    assert_select "aside.workspace-sidebar a.sidebar-link.active .sidebar-link-label", text: "Tags"

    get universe_story_url(universe_slug: @universe.slug, id: @story)
    get universe_tags_url(universe_slug: @universe.slug, scope: "story")

    assert_response :success
    assert_select "main nav[aria-label='Tag scope'] a.active[aria-current='page']", text: "Story Tags"
    assert_select "main nav[aria-label='Story tag workspace'] a", 1
    assert_select "main nav[aria-label='Story tag workspace'] a.active[aria-current='page']", text: "Section tags"
    assert_select "main h1", text: "Tags"
  end

  test "story tag selection is scoped to the selected story" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)
    get universe_tags_url(universe_slug: @universe.slug, scope: "story", taxonomy: "section")

    assert_response :success
    assert_select "main h1", text: "Tags"
    assert_includes response.body, @story.section_tags.first.name
    assert_select "aside.workspace-sidebar a.sidebar-link.active .sidebar-link-label", text: "Tags"
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
    assert_select "main nav[aria-label='Story tag workspace'] a", 1
    assert_select "main .empty-state", text: /Select a story/
  end

  private
    # Each tab is [label, path] or [label, path, sidebar_label] when the workspace
    # sidebar highlights a different entry than the tab label.
    def assert_workspace_tabs(tabs, sidebar_label: nil)
      tabs.each do |tab|
        active_label, path, tab_sidebar_label = tab
        tab_sidebar_label ||= sidebar_label || active_label
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
          text: tab_sidebar_label
      end
    end
end
