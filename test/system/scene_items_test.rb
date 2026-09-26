require "application_system_test_case"

# The Items tab is a read page with a modal editor. What only a browser can prove
# is that the modal adds and edits a role, that a duplicate is explained where the
# author is looking, and that a read-only member sees the same list with nothing
# to click.
class SceneItemsTest < ApplicationSystemTestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
  end

  test "a writer adds an item with a role, edits the role, and removes the link" do
    third = @universe.items.create!(name: "Tannhaus Bell")

    sign_in_via_form(users(:user_one))
    visit universe_story_scene_scene_items_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    assert_selector "h1", text: "Items"
    assert_item_names [ "Item one", "Item two" ]

    click_button "Add item"
    within ".modal.show" do
      select "Tannhaus Bell", from: "Item"
      fill_in "Role", with: "rings at midnight"
      click_button "Save item"
    end

    assert_selector ".entity-row", text: "Tannhaus Bell", wait: REFRESH_WAIT
    assert_text "rings at midnight"
    assert_equal 3, @scene.scene_items.count

    within ".entity-list" do
      find(".entity-row", text: "Tannhaus Bell").find(".dropdown-toggle").click
      click_button "Edit item"
    end
    within ".modal.show" do
      assert_field "Role", with: "rings at midnight"
      assert_equal "Tannhaus Bell", selected_option_text("Item")
      fill_in "Role", with: "silence, finally"
      click_button "Save item"
    end

    assert_selector ".entity-row", text: "silence, finally", wait: REFRESH_WAIT
    assert_equal "silence, finally", @scene.scene_items.joins(:item).find_by(items: { name: "Tannhaus Bell" }).role

    within ".entity-list" do
      find(".entity-row", text: "Tannhaus Bell").find(".dropdown-toggle").click
      accept_confirm("Remove Tannhaus Bell from Scene one?") { click_button "Remove" }
    end

    assert_no_selector ".entity-row", text: "Tannhaus Bell"
    assert_equal 2, @scene.scene_items.count
    # Removing a presence link never removes the item, which is shared by every
    # story in the universe.
    assert Item.exists?(third.id)
  end

  test "a duplicate is refused in the modal, which stays open" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_scene_items_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    # Every universe item is offered, so the most likely mistake is reachable — and
    # has to be explained where the author is looking.
    click_button "Add item"
    within ".modal.show" do
      select "Item one", from: "Item"
      fill_in "Role", with: "carries"
      click_button "Save item"

      assert_selector "[data-modal-form-target='errors'] li", text: "Item is already in this scene"
      assert_selector "select#scene_item_item_id[aria-invalid='true']"
      assert_field "Role", with: "carries"
    end
    assert_selector ".modal.show"
    assert_equal 2, @scene.scene_items.count
  end

  test "a blank role reads as recorded rather than missing" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_scene_items_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    # A blank role is a real state the author chose, so the row says so and still
    # offers the same edit and remove controls as a role-bearing one.
    within find(".entity-row", text: "Item two") do
      assert_text "Role: No role recorded"
      assert_selector ".dropdown.row-actions", count: 1
    end
  end

  test "a read-only member sees the tab without any control" do
    owner = users(:user_one)
    reader = users(:user_two)
    private_universe = Universe.create!(owner: owner, name: "Private props", slug: "private-props", private: true)
    story = Story.create!(universe: private_universe, name: "Private story")
    scene = story.scenes.create!(name: "Private scene")
    scene.scene_items.create!(item: private_universe.items.create!(name: "Reader's prop"), role: "carries")
    UniverseMembership.create!(universe: private_universe, user: reader, access_level: :read)

    sign_in_via_form(reader)
    visit universe_story_scene_scene_items_path(universe_slug: private_universe.slug, story_id: story, scene_id: scene)

    assert_selector ".entity-row", text: "Reader's prop"
    assert_text "Role: carries"
    assert_no_button "Add item"
    assert_no_selector "[data-controller='modal-form']"
    assert_no_selector ".entity-list .dropdown.row-actions"
    # The details link is real navigation, so it renders for every access level.
    assert_selector ".entity-list a.details-link", text: "Details"
  end

  test "the tab is reached from Scene Details as a url-backed workspace tab" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    within "nav[aria-label='Scene workspace']" do
      click_link "Items"
    end

    assert_selector "h1", text: "Items"
    within "nav[aria-label='Scene workspace']" do
      assert_selector "a.active[aria-current='page']", text: "Items"
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

    def assert_item_names(expected)
      actual = page.evaluate_script(
        "Array.from(document.querySelectorAll('.entity-list .entity-title')).map(node => node.textContent.trim())"
      )
      assert_equal expected, actual
    rescue Selenium::WebDriver::Error::JavascriptError, Selenium::WebDriver::Error::NoSuchWindowError
      flunk "could not read the item list"
    end
end
