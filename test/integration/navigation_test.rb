require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  test "without a selected universe only the universe picker is offered" do
    get universes_url

    assert_response :success
    assert_select "aside.workspace-sidebar", 0
    assert_select "aside.right-sidebar", 0
    assert_select "main#main-content", 1
    assert_select "nav .nav-item.dropdown", 1
    assert_select "nav .nav-item.dropdown .dropdown-toggle", text: "Universes"
    assert_select ".page-header h1", text: "Universes"
    assert_select "a", text: "Dashboard", count: 0
    assert_select "aside", text: /Universe Analyzer/, count: 0
  end

  test "a selected universe shows the workspace, direct Bible links, and tools" do
    get universe_url(@universe)

    assert_response :success
    assert_select "nav .nav-item.dropdown", 3
    assert_select "nav .nav-item.dropdown .dropdown-toggle", text: /Universe: #{@universe.name}/
    assert_select "nav .nav-item.dropdown .dropdown-toggle", text: /Story: Select/
    assert_select "nav .dropdown-menu a[href=?]",
      universe_story_path(universe_slug: @universe.slug, id: @story)
    assert_select "nav .dropdown-menu a[href=?]",
      new_universe_story_path(universe_slug: @universe.slug)

    assert_select "aside.workspace-sidebar .sidebar-section-title", text: "Story workspace"
    assert_select "aside.workspace-sidebar .sidebar-section-title", text: "Universe Bible"
    assert_select "aside.workspace-sidebar .sidebar-section-title", text: "Configuration"
    assert_select "aside.workspace-sidebar a", text: "All stories"
    assert_select "aside.workspace-sidebar a", text: "New story", count: 0
    assert_select "aside.workspace-sidebar a.sidebar-link[href='#'][aria-disabled=true][data-placeholder-link=true]",
      text: /Scenes/
    assert_select "aside.workspace-sidebar a.sidebar-link[href=?]",
      universe_story_sections_path(universe_slug: @universe.slug, story_id: @story),
      count: 0

    assert_select "aside.workspace-sidebar section[aria-labelledby='universe-bible-title'] .sidebar-group-title", 0
    {
      characters: universe_characters_path(universe_slug: @universe.slug),
      locations: universe_locations_path(universe_slug: @universe.slug),
      events: universe_events_path(universe_slug: @universe.slug),
      timeline: universe_timeline_path(universe_slug: @universe.slug),
      items: universe_items_path(universe_slug: @universe.slug)
    }.each do |label, path|
      assert_select "aside.workspace-sidebar section[aria-labelledby='universe-bible-title'] a.sidebar-link[href=?]",
        path do
        assert_select ".sidebar-link-label", text: label.to_s.capitalize
      end
    end
    assert_select "aside.workspace-sidebar a[href=?]",
      universe_relations_path(universe_slug: @universe.slug), count: 0
    assert_select "aside.workspace-sidebar a[href=?]",
      universe_ownerships_path(universe_slug: @universe.slug), count: 0

    assert_select "aside.workspace-sidebar #tag-navigation-menu-label", text: /Tags/
    assert_select "aside.workspace-sidebar #tag-navigation-menu .dropdown-item", 6
    assert_select "aside.workspace-sidebar #tag-navigation-menu a[href=?]",
      universe_story_section_tags_path(universe_slug: @universe.slug, story_id: @story), count: 0

    assert_select "aside.right-sidebar.offcanvas-xl.offcanvas-end", 1
    assert_select "button[data-bs-target='#workspace-tools-navigation']", text: /Tools/
    assert_select "aside.right-sidebar .sidebar-section-title", text: "Collaboration"
    assert_select "aside.right-sidebar .sidebar-section-title", text: "Analytics"
    assert_select "aside.right-sidebar .sidebar-section-title", text: "AI"
    assert_select "aside.right-sidebar a.sidebar-placeholder-link[href='#']", minimum: 3
  end

  test "a selected story adds story structure and the full tag menu" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)

    assert_response :success
    assert_select "nav .nav-item.dropdown", 3
    assert_select "nav .nav-item.dropdown .dropdown-toggle", text: /Story: #{@story.name}/
    assert_select "nav .dropdown-menu a.active[href=?]",
      universe_story_path(universe_slug: @universe.slug, id: @story)

    assert_select "aside.workspace-sidebar .sidebar-section-title", text: "Story workspace"
    assert_select "aside.workspace-sidebar a.sidebar-link[href=?]",
      universe_story_sections_path(universe_slug: @universe.slug, story_id: @story) do
      assert_select ".sidebar-link-label", text: "Sections"
      assert_select ".sidebar-count", text: "2"
    end
    assert_select "aside.workspace-sidebar a.sidebar-link[href='#']", text: /Scenes/
    assert_select "aside.workspace-sidebar #tag-navigation-menu .dropdown-item", 7
    assert_select "aside.workspace-sidebar #tag-navigation-menu a[href=?]",
      universe_story_section_tags_path(universe_slug: @universe.slug, story_id: @story),
      text: "Section tags"

    {
      character_tags: universe_character_tags_path(universe_slug: @universe.slug),
      relation_tags: universe_relation_tags_path(universe_slug: @universe.slug),
      location_tags: universe_location_tags_path(universe_slug: @universe.slug),
      event_tags: universe_event_tags_path(universe_slug: @universe.slug),
      item_tags: universe_item_tags_path(universe_slug: @universe.slug),
      ownership_tags: universe_ownership_tags_path(universe_slug: @universe.slug)
    }.each do |label, path|
      assert_select "aside.workspace-sidebar #tag-navigation-menu a[href=?]", path,
        text: label.to_s.sub("_tags", " tags").capitalize
    end

    {
      characters: universe_characters_path(universe_slug: @universe.slug),
      locations: universe_locations_path(universe_slug: @universe.slug),
      events: universe_events_path(universe_slug: @universe.slug),
      timeline: universe_timeline_path(universe_slug: @universe.slug),
      items: universe_items_path(universe_slug: @universe.slug)
    }.each do |label, path|
      assert_select "aside.workspace-sidebar a.sidebar-link[href=?]", path do
        assert_select ".sidebar-link-label", text: label.to_s.capitalize
      end
    end

    # The selected story is remembered for the rest of the session.
    get universe_url(@universe)
    assert_select "aside.workspace-sidebar a.sidebar-link[href=?]",
      universe_story_path(universe_slug: @universe.slug, id: @story),
      text: /Story overview/
  end

  test "another page of the same universe keeps the story context" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "nav .nav-item.dropdown .dropdown-toggle", text: /Story: #{@story.name}/
    assert_select "aside.workspace-sidebar a.sidebar-link.active[aria-current=page][href=?]",
      universe_characters_path(universe_slug: @universe.slug)
    assert_select "aside.workspace-sidebar a.sidebar-link[href=?]",
      universe_story_sections_path(universe_slug: @universe.slug, story_id: @story)
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]",
      universe_characters_path(universe_slug: @universe.slug)
    assert_select "nav.content-tabs a[href=?]",
      universe_relations_path(universe_slug: @universe.slug)
  end
end
