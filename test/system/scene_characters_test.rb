require "application_system_test_case"

# The Characters tab is a read page with a modal editor, and it shows two
# participation sources side by side. What only a browser can prove is that the
# modal adds and edits a role, that a derived speaker appears without a stored
# record and without an editable control, and that a read-only member sees the
# same list with nothing to click.
class SceneCharactersTest < ApplicationSystemTestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
  end

  test "a writer adds a participant with a role, edits the role, and removes the link" do
    third = @universe.characters.create!(name: "Charlotte")

    sign_in_via_form(users(:user_one))
    visit universe_story_scene_scene_characters_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    assert_selector "h1", text: "Characters"
    assert_character_names [ "Character one", "Character two" ]

    click_button "Add character"
    within ".modal.show" do
      select "Charlotte", from: "Character"
      fill_in "Role", with: "waits in the car"
      click_button "Save character"
    end

    assert_selector ".entity-row", text: "Charlotte", wait: REFRESH_WAIT
    assert_text "waits in the car"
    assert_equal 3, @scene.scene_characters.count

    within ".entity-list" do
      find(".entity-row", text: "Charlotte").find(".dropdown-toggle").click
      click_button "Edit role"
    end
    within ".modal.show" do
      assert_field "Role", with: "waits in the car"
      assert_equal "Charlotte", selected_option_text("Character")
      fill_in "Role", with: "drives"
      click_button "Save character"
    end

    assert_selector ".entity-row", text: "drives", wait: REFRESH_WAIT
    assert_equal "drives", @scene.scene_characters.joins(:character).find_by(characters: { name: "Charlotte" }).role

    within ".entity-list" do
      find(".entity-row", text: "Charlotte").find(".dropdown-toggle").click
      accept_confirm("Remove Charlotte from Scene one?") { click_button "Remove" }
    end

    assert_no_selector ".entity-row", text: "Charlotte"
    assert_equal 2, @scene.scene_characters.count
    # Removing a presence link never removes the character.
    assert Character.exists?(third.id)
  end

  test "a character who only speaks is listed without a control to edit" do
    passer_by = @universe.characters.create!(name: "Passer-by")
    scene = @story.scenes.create!(name: "Street")
    scene.scene_elements.create!(name: "Passing", kind: "dialogue", characters: [ passer_by ])

    sign_in_via_form(users(:user_one))
    visit universe_story_scene_scene_characters_path(universe_slug: @universe.slug, story_id: @story, scene_id: scene)

    assert_selector ".entity-row", text: "Passer-by"
    within ".entity-list" do
      row = find(".entity-row", text: "Passer-by")
      assert_no_selector "span.badge", text: "Participant"
      assert_text "Speaks in 1 element"
      assert_no_selector ".dropdown.row-actions"
    end
  end

  test "a duplicate is refused in the modal, which stays open" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_scene_characters_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    # Every universe character is offered, so the most likely mistake is
    # reachable — and has to be explained where the author is looking.
    click_button "Add character"
    within ".modal.show" do
      select "Character one", from: "Character"
      fill_in "Role", with: "setting"
      click_button "Save character"

      assert_selector "[data-modal-form-target='errors'] li", text: "Character is already in this scene"
      assert_selector "select#scene_character_character_id[aria-invalid='true']"
      assert_field "Role", with: "setting"
    end
    assert_selector ".modal.show"
    assert_equal 2, @scene.scene_characters.count
  end

  test "a stored participant who also speaks is one row labelled as both" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_scene_characters_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    # Both stored participants also speak in `dialogue_one`, and the union is two
    # rows rather than four.
    assert_character_names [ "Character one", "Character two" ]
    within ".entity-list" do
      row = find(".entity-row", text: "Character one")
      assert_text "Participant"
      assert_text "Speaks in 1 element"
      assert_text "Role: setting"
    end
  end

  test "a read-only member sees the tab without any control" do
    owner = users(:user_one)
    reader = users(:user_two)
    private_universe = Universe.create!(owner: owner, name: "Private cast", slug: "private-cast", private: true)
    story = Story.create!(universe: private_universe, name: "Private story")
    scene = story.scenes.create!(name: "Private scene")
    scene.scene_characters.create!(character: private_universe.characters.create!(name: "Reader"), role: "setting")
    UniverseMembership.create!(universe: private_universe, user: reader, access_level: :read)

    sign_in_via_form(reader)
    visit universe_story_scene_scene_characters_path(universe_slug: private_universe.slug, story_id: story, scene_id: scene)

    assert_selector ".entity-row", text: "Reader"
    assert_text "Role: setting"
    assert_no_button "Add character"
    assert_no_selector "[data-controller='modal-form']"
    assert_no_selector ".entity-list .dropdown.row-actions"
    # The details link is real navigation, so it renders for every access level.
    assert_selector ".entity-list a.details-link", text: "Details"
  end

  test "the tab is reached from Scene Details as a url-backed workspace tab" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    within "nav[aria-label='Scene workspace']" do
      click_link "Characters"
    end

    assert_selector "h1", text: "Characters"
    within "nav[aria-label='Scene workspace']" do
      assert_selector "a.active[aria-current='page']", text: "Characters"
      # The two presence tabs that have not shipped stay placeholders.
      assert_selector "span.nav-link.disabled[aria-disabled='true']", count: 2
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

    def assert_character_names(expected)
      actual = page.evaluate_script(
        "Array.from(document.querySelectorAll('.entity-list .entity-title')).map(node => node.textContent.trim())"
      )
      assert_equal expected, actual
    rescue Selenium::WebDriver::Error::JavascriptError, Selenium::WebDriver::Error::NoSuchWindowError
      flunk "could not read the character list"
    end
end
