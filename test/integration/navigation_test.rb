require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  test "without a selected universe the top bar only offers the landing page" do
    get universes_url

    assert_response :success
    assert_select "aside.workspace-sidebar", 0
    assert_select "aside.right-sidebar", 0
    assert_select "main#main-content", 1
    # The brand is the landing page, so it is the only scope link there is. There
    # is no universe picker in the top bar: this page is the picker.
    assert_select "nav a.navbar-brand[href=?]", root_path, text: "Universe Maker"
    assert_select "nav .navbar-nav .nav-item", 0
    assert_select "nav .navbar-nav a", 0
    # The account menu is the top bar's only dropdown.
    assert_select "nav .dropdown", 1
    assert_select ".page-header h1", text: "Universes"
    assert_select ".page-actions a", text: /New universe/
    assert_select "a", text: "Dashboard", count: 0
    assert_select "aside", text: /Universe Analyzer/, count: 0
  end

  test "a selected universe shows the workspace, direct Bible links, and tools" do
    get universe_url(@universe)

    assert_response :success
    assert_select "nav a.navbar-brand[href=?]", root_path, text: "Universe Maker"
    # The top bar states the current universe and links to its own page. It
    # carries no switcher, so no story link exists until a story is current.
    assert_select "nav .navbar-nav .nav-item", 1
    assert_select "nav .navbar-nav a.nav-link[href=?]", universe_path(@universe),
      text: /Universe: #{@universe.name}/
    assert_select "nav .navbar-nav a.nav-link[aria-current=page]", 1
    assert_select "nav .dropdown", 1

    assert_select "aside.workspace-sidebar .sidebar-section-title", text: "Story workspace"
    assert_select "aside.workspace-sidebar .sidebar-section-title", text: "Universe Bible"
    assert_select "aside.workspace-sidebar .sidebar-section-title", text: "Configuration", count: 0
    assert_select "aside.workspace-sidebar a", text: "All stories"
    assert_select "aside.workspace-sidebar a", text: "New story", count: 0
    assert_select "aside.workspace-sidebar a.sidebar-link[href='#'][aria-disabled=true][data-placeholder-link=true]",
      text: /Scenes/
    assert_select "aside.workspace-sidebar a[href=?]",
      universe_story_scenes_path(universe_slug: @universe.slug, story_id: @story),
      count: 0
    assert_select "aside.workspace-sidebar a[href=?]",
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

    # Configuration and Tags moved to the right utility sidebar, so the left
    # column keeps no tools section and no taxonomy entry.
    assert_select "aside.workspace-sidebar section[aria-labelledby='configuration-title']", count: 0
    assert_select "aside.workspace-sidebar a[href=?]",
      universe_tags_path(universe_slug: @universe.slug), count: 0
    assert_select "aside.workspace-sidebar a", text: "Tags", count: 0
    assert_select "aside.workspace-sidebar a", text: "Members", count: 0

    assert_select "aside.right-sidebar.offcanvas-xl.offcanvas-end", 1
    assert_select "button[data-bs-target='#workspace-tools-navigation']", text: /Tools/
    assert_select "aside.right-sidebar .sidebar-section-title", text: "Configuration"
    assert_select "aside.right-sidebar .sidebar-section-title", text: "Collaboration"
    assert_select "aside.right-sidebar .sidebar-section-title", text: "Analytics"
    assert_select "aside.right-sidebar .sidebar-section-title", text: "AI"
    assert_select "aside.right-sidebar .sidebar-section-title", text: "Settings", count: 0
    assert_select "aside.right-sidebar .sidebar-context--tools .sidebar-eyebrow", text: "Universe tools"
    assert_select "aside.right-sidebar section[aria-labelledby='configuration-title'] a.sidebar-link", text: "Tags"
    assert_select "aside.right-sidebar section[aria-labelledby='configuration-title'] a.sidebar-link[href=?]",
      universe_tags_path(universe_slug: @universe.slug)
    assert_select "aside.right-sidebar section[aria-labelledby='configuration-title'] a.sidebar-link", text: "Members"
    assert_select "aside.right-sidebar a.sidebar-placeholder-link[href='#']", minimum: 3
  end

  test "the universe page is the story picker and owns New story" do
    get universe_url(@universe)

    assert_response :success
    assert_select ".page-actions a[href=?]", new_universe_story_path(universe_slug: @universe.slug),
      text: /New story/
    assert_select ".page-actions a[href=?]", universe_stories_path(universe_slug: @universe.slug),
      text: "All stories"
    assert_select ".list-group a[href=?]",
      universe_story_path(universe_slug: @universe.slug, id: @story), text: @story.name
  end

  test "a read-only member and a guest are not offered New story" do
    private_universe = Universe.create!(owner: users(:user_two), name: "Private universe", private: true)
    UniverseMembership.create!(universe: private_universe, user: users(:user_one), access_level: :read)

    get universe_url(private_universe)
    assert_response :success
    assert_select ".page-actions a[href=?]", new_universe_story_path(universe_slug: private_universe.slug),
      count: 0

    sign_out
    get universe_url(@universe)
    assert_response :success
    assert_select ".page-actions a[href=?]", new_universe_story_path(universe_slug: @universe.slug), count: 0
  end

  test "a guest keeps Tags in the right Configuration section without Members" do
    sign_out
    get universe_url(@universe)

    assert_response :success
    assert_select "aside.right-sidebar section[aria-labelledby='configuration-title'] a.sidebar-link", text: "Tags"
    assert_select "aside.right-sidebar section[aria-labelledby='configuration-title'] a.sidebar-link",
      text: "Members", count: 0
  end

  test "a selected story adds story structure while the right Configuration contains Tags" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)

    assert_response :success
    # Both scopes are plain links now, and only the page being viewed is current.
    assert_select "nav .navbar-nav .nav-item", 2
    assert_select "nav .navbar-nav a.nav-link[href=?]",
      universe_story_path(universe_slug: @universe.slug, id: @story),
      text: /Story: #{@story.name}/
    assert_select "nav .navbar-nav a.nav-link[href=?][aria-current=page].active",
      universe_story_path(universe_slug: @universe.slug, id: @story)
    assert_select "nav .navbar-nav a.nav-link[href=?][aria-current=page]",
      universe_path(@universe), count: 0
    assert_select "nav .dropdown", 1

    assert_select "aside.workspace-sidebar .sidebar-section-title", text: "Story workspace"
    assert_select "aside.workspace-sidebar a.sidebar-link[href=?]",
      universe_story_sections_path(universe_slug: @universe.slug, story_id: @story) do
      assert_select ".sidebar-link-label", text: "Sections"
      assert_select ".sidebar-count", text: "2"
    end
    assert_select "aside.workspace-sidebar a.sidebar-link[href=?]",
      universe_story_scenes_path(universe_slug: @universe.slug, story_id: @story) do
      assert_select ".sidebar-link-label", text: "Scenes"
      assert_select ".sidebar-count", text: "3"
    end
    assert_select "aside.workspace-sidebar a.sidebar-link[href='#']", text: /Scenes/, count: 0
    assert_select "aside.workspace-sidebar a[href=?]",
      universe_tags_path(universe_slug: @universe.slug), count: 0
    assert_select "aside.right-sidebar section[aria-labelledby='configuration-title'] a.sidebar-link", text: "Tags"
    assert_select "aside.right-sidebar section[aria-labelledby='configuration-title'] a.sidebar-link", text: "Members"
    assert_select "aside.workspace-sidebar a[href=?]",
      universe_story_section_tags_path(universe_slug: @universe.slug, story_id: @story), count: 0
    assert_select "aside.workspace-sidebar a[href=?]",
      universe_story_scene_tags_path(universe_slug: @universe.slug, story_id: @story), count: 0

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

  test "another page of the same universe keeps the story context without claiming to be current" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "nav .navbar-nav a.nav-link[href=?]",
      universe_story_path(universe_slug: @universe.slug, id: @story),
      text: /Story: #{@story.name}/
    assert_select "nav .navbar-nav a.nav-link[aria-current=page]", 0
    assert_select "aside.workspace-sidebar a.sidebar-link.active[aria-current=page][href=?]",
      universe_characters_path(universe_slug: @universe.slug)
    assert_select "aside.workspace-sidebar a.sidebar-link[href=?]",
      universe_story_sections_path(universe_slug: @universe.slug, story_id: @story)
    assert_select "nav.content-tabs a", 2
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]",
      universe_characters_path(universe_slug: @universe.slug)
    {
      characters: universe_characters_path(universe_slug: @universe.slug),
      relations: universe_relations_path(universe_slug: @universe.slug)
    }.each do |label, path|
      assert_select "nav.content-tabs a[href=?]", path, text: label.to_s.capitalize
    end
  end

  test "settings is a top bar entry on every page, not a Configuration link" do
    # A theme belongs to the browser rather than to a universe, so the entry
    # follows the reader out of the workspace, and the Configuration section
    # stays about universe configuration.
    [ universes_url, universe_url(@universe), universe_story_url(universe_slug: @universe.slug, id: @story) ].each do |path|
      get path

      assert_response :success
      assert_select "nav.navbar .navbar-actions a[href=?]", settings_path, text: /Settings/
      assert_select "nav.navbar .navbar-actions a[href=?][aria-current=page]", settings_path, count: 0
      assert_select "aside.right-sidebar a[href=?]", settings_path, count: 0
      assert_select "aside.workspace-sidebar a[href=?]", settings_path, count: 0
    end
  end
end
