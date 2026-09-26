require "application_system_test_case"

# The Locations tab is a read page with a modal editor, and it is the only Scene
# workspace whose rows are hierarchical. What only a browser can prove is that a
# nested place is shown with its ancestor path and offered in the picker in tree
# order, that the modal adds and edits a role, and that a read-only member sees
# the same list with nothing to click.
class SceneLocationsTest < ApplicationSystemTestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
  end

  test "a writer adds a location with a role, edits the role, and removes the link" do
    third = @universe.locations.create!(name: "Winden Forest")

    sign_in_via_form(users(:user_one))
    visit universe_story_scene_scene_locations_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    assert_selector "h1", text: "Locations"
    assert_location_names [ "Location one", "Location two" ]

    click_button "Add location"
    within ".modal.show" do
      select "Winden Forest", from: "Location"
      fill_in "Role", with: "the search"
      click_button "Save location"
    end

    assert_selector ".entity-row", text: "Winden Forest", wait: REFRESH_WAIT
    assert_text "the search"
    assert_equal 3, @scene.scene_locations.count

    within ".entity-list" do
      find(".entity-row", text: "Winden Forest").find(".dropdown-toggle").click
      click_button "Edit location"
    end
    within ".modal.show" do
      assert_field "Role", with: "the search"
      assert_equal "Winden Forest", selected_option_text("Location")
      fill_in "Role", with: "the hollow tree"
      click_button "Save location"
    end

    assert_selector ".entity-row", text: "the hollow tree", wait: REFRESH_WAIT
    assert_equal "the hollow tree",
      @scene.scene_locations.joins(:location).find_by(locations: { name: "Winden Forest" }).role

    within ".entity-list" do
      find(".entity-row", text: "Winden Forest").find(".dropdown-toggle").click
      accept_confirm("Remove Winden Forest from Scene one?") { click_button "Remove" }
    end

    assert_no_selector ".entity-row", text: "Winden Forest"
    assert_equal 2, @scene.scene_locations.count
    # Removing a presence link never removes the place, and never its nested
    # places: the Location is shared by every story in the universe.
    assert Location.exists?(third.id)
  end

  test "a nested place is shown with its ancestor path" do
    @universe.locations.create!(name: "Martha Room", parent: locations(:location_one))
    @scene.scene_locations.create!(location: @universe.locations.find_by!(name: "Martha Room"), role: "waits in")

    sign_in_via_form(users(:user_one))
    visit universe_story_scene_scene_locations_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    assert_selector ".entity-row", text: "Location one / Martha Room"
  end

  test "the picker offers nested places after their parent" do
    @universe.locations.create!(name: "Martha Room", parent: locations(:location_one))

    sign_in_via_form(users(:user_one))
    visit universe_story_scene_scene_locations_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    click_button "Add location"
    option_texts = within(".modal.show") do
      find("select[name='scene_location[location_id]']").all("option").map(&:text)
    end

    parent_index = option_texts.index("Location one")
    child_index = option_texts.index("— Martha Room")
    assert parent_index, "the parent must be offered"
    assert child_index, "the nested place must be offered, indented"
    assert_operator parent_index, :<, child_index
  end

  test "a duplicate is refused in the modal, which stays open" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_scene_locations_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    # Every universe location is offered, so the most likely mistake is reachable —
    # and has to be explained where the author is looking.
    click_button "Add location"
    within ".modal.show" do
      select "Location one", from: "Location"
      fill_in "Role", with: "setting"
      click_button "Save location"

      assert_selector "[data-modal-form-target='errors'] li", text: "Location is already in this scene"
      assert_selector "select#scene_location_location_id[aria-invalid='true']"
      assert_field "Role", with: "setting"
    end
    assert_selector ".modal.show"
    assert_equal 2, @scene.scene_locations.count
  end

  test "a read-only member sees the tab without any control" do
    owner = users(:user_one)
    reader = users(:user_two)
    private_universe = Universe.create!(owner: owner, name: "Private places", slug: "private-places", private: true)
    story = Story.create!(universe: private_universe, name: "Private story")
    scene = story.scenes.create!(name: "Private scene")
    scene.scene_locations.create!(location: private_universe.locations.create!(name: "Reader's house"), role: "setting")
    UniverseMembership.create!(universe: private_universe, user: reader, access_level: :read)

    sign_in_via_form(reader)
    visit universe_story_scene_scene_locations_path(universe_slug: private_universe.slug, story_id: story,
      scene_id: scene)

    assert_selector ".entity-row", text: "Reader's house"
    assert_text "Role: setting"
    assert_no_button "Add location"
    assert_no_selector "[data-controller='modal-form']"
    assert_no_selector ".entity-list .dropdown.row-actions"
    # The details link is real navigation, so it renders for every access level.
    assert_selector ".entity-list a.details-link", text: "Details"
  end

  test "the tab is reached from Scene Details as a url-backed workspace tab" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    within "nav[aria-label='Scene workspace']" do
      click_link "Locations"
    end

    assert_selector "h1", text: "Locations"
    within "nav[aria-label='Scene workspace']" do
      assert_selector "a.active[aria-current='page']", text: "Locations"
      # Every workspace tab has a real destination now, so none is a placeholder.
      assert_selector "span.nav-link.disabled[aria-disabled='true']", count: 0
    end
  end

  private
    # The label the author sees for the current selection, rather than the id the
    # control stores. Selecting an option sets its property, not its attribute, so
    # it is read through the DOM instead of a CSS selector.
    def selected_option_text(label)
      id = find_field(label)[:id]
      page.evaluate_script("document.getElementById('#{id}').selectedOptions[0].textContent")
    end

    def assert_location_names(expected)
      actual = page.evaluate_script(
        "Array.from(document.querySelectorAll('.entity-list .entity-title')).map(node => node.textContent.trim())"
      )
      assert_equal expected, actual
    rescue Selenium::WebDriver::Error::JavascriptError, Selenium::WebDriver::Error::NoSuchWindowError
      flunk "could not read the location list"
    end
end
