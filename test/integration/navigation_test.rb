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
    assert_select "aside", 0
    assert_select "nav .nav-item.dropdown", 1
    assert_select "nav .dropdown-toggle", text: "Universes"
    assert_select "nav a.nav-link.active", 0
  end
  test "a selected universe shows its menus but keeps the story cards hidden" do
    get universe_url(@universe)

    assert_response :success

    # Universe menu in the top bar, listing this universe's stories.
    assert_select "nav .nav-item.dropdown", 2
    assert_select "nav .dropdown-toggle", text: @universe.name
    assert_select "nav .dropdown-menu a[href=?]",
      universe_story_path(universe_slug: @universe.slug, id: @story)
    assert_select "nav .dropdown-menu a[href=?]",
      new_universe_story_path(universe_slug: @universe.slug)

    # No story is selected yet: WHAT/HOW stay hidden, the red cards show.
    assert_select "aside.left-sidebar .card-header", { count: 0, text: /WHAT/ }
    assert_select "aside.left-sidebar .card-header", { count: 0, text: /HOW/ }
    assert_select "aside.left-sidebar .card-header", text: /WHO/
    assert_select "aside.left-sidebar a", { count: 0, text: /Story One/ }
    assert_select "nav a.nav-link.active", 0
  end

  test "a selected story adds the story cards and the current story menu" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)

    assert_response :success
    assert_select "aside.left-sidebar .card-header", text: /WHAT/
    assert_select "aside.left-sidebar .card-header", text: /HOW/
    assert_select "aside.left-sidebar .card-header", text: /WHO/

    assert_select "nav a.nav-link.active[href=?]",
      universe_story_path(universe_slug: @universe.slug, id: @story)
    assert_select "nav .dropdown-menu a.active[href=?]",
      universe_story_path(universe_slug: @universe.slug, id: @story)

    # The selected story is remembered for the rest of the session.
    get universe_url(@universe)
    assert_select "aside.left-sidebar .card-header", text: /WHAT/
  end

  test "another page of the same universe keeps the selection" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "aside.left-sidebar .card-header", text: /HOW/
  end
end
