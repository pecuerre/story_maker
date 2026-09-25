require "application_system_test_case"

# The Scenes list is the page a large story spends most of its time on, so the
# search area is covered in the browser: the filter must narrow the list, stay in
# the URL, survive a list-embedded reorder, and be removable.
class SceneFilterTest < ApplicationSystemTestCase
  test "a writer narrows the scene list, sees it in the URL, and clears it" do
    universe = universes(:universe_one)
    story = stories(:story_one)

    sign_in_via_form(users(:user_one))
    visit universe_story_scenes_path(universe_slug: universe.slug, story_id: story)
    assert_scene_titles [ "Scene one", "Scene two", "Scene three" ]

    fill_in "Search", with: "second"
    click_button "Filter scenes"

    assert_current_path scenes_path(universe, story, q: "second")
    assert_scene_titles [ "Scene two" ]
    assert_text "Showing 1 scene of 3 scenes"
    assert_text "Search: “second”"
    # A narrowed row still says where it sits in the whole narrative order.
    assert_selector ".entity-row .badge", text: "2"

    fill_in "Search", with: ""
    select "Section one", from: "Section"
    click_button "Filter scenes"

    assert_current_path scenes_path(universe, story, section_id: sections(:section_one).id)
    assert_scene_titles [ "Scene one" ]

    click_link "Clear filters"

    assert_current_path scenes_path(universe, story)
    assert_scene_titles [ "Scene one", "Scene two", "Scene three" ]
    assert_no_link "Clear filters"
  end

  test "a filtered list keeps its filter through a reorder and reports no match separately" do
    universe = universes(:universe_one)
    story = stories(:story_one)

    sign_in_via_form(users(:user_one))
    visit universe_story_scenes_path(universe_slug: universe.slug, story_id: story)

    fill_in "Search", with: "no such scene"
    click_button "Filter scenes"

    assert_selector ".empty-title", text: "No scenes match these filters"
    assert_selector ".empty-description", text: "Story One has 3 scenes, but none of them match"
    within ".empty-state" do
      click_link "Clear filters"
    end
    assert_scene_titles [ "Scene one", "Scene two", "Scene three" ]

    # Reordering inside a narrowed list moves the scene in the real sequence and
    # keeps the author in the same view.
    fill_in "Search", with: "three"
    click_button "Filter scenes"
    within ".entity-list" do
      find(".entity-row", text: "Scene three").find("button[data-scene-move='up']").click
    end

    assert_selector ".alert-success, .alert-danger"
    assert_scene_titles [ "Scene three" ]
    assert_current_path scenes_path(universe, story, q: "three")
    assert_equal [ scenes(:scene_one), scenes(:scene_three), scenes(:scene_two) ],
      story.scenes.reorder(:position, :id).to_a
  end

  test "a guest filters with the keyboard alone at a narrow width" do
    universe = universes(:universe_one)
    story = stories(:story_one)

    page.driver.browser.manage.window.resize_to(420, 900)
    visit universe_story_scenes_path(universe_slug: universe.slug, story_id: story)
    assert_scene_titles [ "Scene one", "Scene two", "Scene three" ]
    assert_no_link "Add scene"

    # Typing and pressing Enter is the whole keyboard path: the search field
    # submits its form, so no pointer is needed for the filter to apply.
    find("#scene_filter_q").send_keys("second", :return)

    assert_current_path scenes_path(universe, story, q: "second")
    assert_scene_titles [ "Scene two" ]
    assert_no_selector ".dropdown.row-actions"
    assert_no_horizontal_overflow
  end

  private
    # The filter is a form of selects, date fields, and badges, so a narrow
    # viewport has to fold it instead of widening the page.
    def assert_no_horizontal_overflow
      scroll_width, viewport_width = page.evaluate_script(
        "[document.documentElement.scrollWidth, window.innerWidth]"
      )

      assert_operator scroll_width, :<=, viewport_width + 1
    end

    # The filter lives in the query string, so the expected path carries it.
    def scenes_path(universe, story, **filter)
      universe_story_scenes_path(universe_slug: universe.slug, story_id: story, **filter)
    end

    # Turbo re-renders the list after a redirect, so an immediate read of the
    # order can still see the previous page. Poll until it settles.
    def assert_scene_titles(expected)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
      actual = scene_titles
      while actual != expected && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        sleep 0.1
        actual = scene_titles
      end

      assert_equal expected, actual
    end

    def scene_titles
      # Read the order in one shot: a Turbo re-render can detach element handles
      # between a query and a read, which is not what this assertion is about.
      page.evaluate_script(
        "Array.from(document.querySelectorAll('.entity-list .entity-title')).map(node => node.textContent.trim())"
      )
    rescue Selenium::WebDriver::Error::JavascriptError, Selenium::WebDriver::Error::NoSuchWindowError
      nil
    end
end
