require "application_system_test_case"

class SceneNarrativeOrderTest < ApplicationSystemTestCase
  test "a writer creates, reorders, edits, and deletes scenes in narrative order" do
    universe = universes(:universe_one)
    story = stories(:story_one)

    sign_in_via_form(users(:user_one))
    visit universe_story_scenes_path(universe_slug: universe.slug, story_id: story)

    assert_selector "h1", text: "Scenes"
    assert_scene_titles [ "Scene one", "Scene two", "Scene three" ]
    assert_selector "form[action$='/move'] button[data-scene-move=up][disabled]", count: 1
    assert_selector "form[action$='/move'] button[data-scene-move=down][disabled]", count: 1

    click_link "Add scene"
    assert_selector "h1", text: "New scene"
    fill_in "Title", with: "Browser scene"
    fill_in "Short description", with: "Created from a system test."
    click_button "Create Scene"

    assert_selector "h1", text: "Browser scene"
    assert_selector ".alert-success", text: "Scene was successfully created."

    visit universe_story_scenes_path(universe_slug: universe.slug, story_id: story)
    assert_scene_titles [ "Scene one", "Scene two", "Scene three", "Browser scene" ]

    move_scene "Browser scene", "up"
    assert_scene_titles [ "Scene one", "Scene two", "Browser scene", "Scene three" ]

    # Moving the same scene again must reorder, never duplicate or drop a record.
    move_scene "Browser scene", "up"
    assert_scene_titles [ "Scene one", "Browser scene", "Scene two", "Scene three" ]

    move_scene "Browser scene", "down"
    assert_scene_titles [ "Scene one", "Scene two", "Browser scene", "Scene three" ]

    within ".entity-list" do
      find(".entity-row", text: "Browser scene").find(".dropdown-toggle").click
      click_link "Edit"
    end
    assert_selector "h1", text: "Edit scene"
    fill_in "Short description", with: "Renamed summary from the browser."
    click_button "Update Scene"

    assert_selector "h1", text: "Browser scene"
    assert_text "Renamed summary from the browser."

    visit universe_story_scenes_path(universe_slug: universe.slug, story_id: story)
    within ".entity-list" do
      find(".entity-row", text: "Browser scene").find(".dropdown-toggle").click
      accept_confirm do
        click_button "Delete"
      end
    end

    assert_selector ".alert-success", text: "Scene was successfully destroyed."
    assert_scene_titles [ "Scene one", "Scene two", "Scene three" ]
  end

  test "a read-only member sees the scene list and details without mutation controls" do
    owner = users(:user_one)
    reader = users(:user_two)
    private_universe = Universe.create!(owner: owner, name: "Private scenes", slug: "private-scenes", private: true)
    story = Story.create!(universe: private_universe, name: "Private story")
    scene = story.scenes.create!(name: "Private scene", description: "Read-only details")
    UniverseMembership.create!(universe: private_universe, user: reader, access_level: :read)

    sign_in_via_form(reader)
    visit universe_story_scenes_path(universe_slug: private_universe.slug, story_id: story)

    assert_selector "h1", text: "Scenes"
    assert_selector ".entity-list a[href='#{universe_story_scene_path(universe_slug: private_universe.slug, story_id: story, id: scene)}']",
      text: "Private scene"
    assert_no_link "Add scene"
    assert_no_selector "form[action$='/move']"
    assert_no_selector ".dropdown.row-actions"

    visit universe_story_scene_path(universe_slug: private_universe.slug, story_id: story, id: scene)

    assert_selector "h1", text: "Private scene"
    assert_text "Read-only details"
    assert_no_link "Edit scene"
    assert_no_selector "form[action$='/scenes/']"
  end

  private
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

    def move_scene(title, direction)
      within ".entity-list" do
        find(".entity-row", text: title).find("button[data-scene-move='#{direction}']").click
      end
      # Every move redirects and re-renders the list from the server; the caller
      # waits for the resulting order.
      assert_selector ".alert-success, .alert-danger"
    end
end
