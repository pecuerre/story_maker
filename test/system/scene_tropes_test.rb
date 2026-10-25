require "application_system_test_case"

# The Tropes tab is a read page with a modal editor, exactly like the Characters,
# Items, and Locations tabs. What only a browser can prove is that the picker
# records one reference with its context note, that the note can be edited, that
# removing the assignment keeps the shared reference, and that a read-only member
# sees the list with nothing to click.
class SceneTropesTest < ApplicationSystemTestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
  end

  test "a writer adds a trope with a note, edits the note, and removes the assignment" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_scene_tropes_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    assert_selector "h1", text: "Tropes"
    assert_selector ".entity-title", text: "Red Herring"

    click_button "Add trope"
    within ".modal.show" do
      choose_trope "Chekhov’s Gun", query: "chek"
      fill_in "Context note", with: "The detail pays off later."
      assert_field "Context note", with: "The detail pays off later."
      click_button "Save trope"
    end

    assert_selector ".entity-row", text: "Chekhov’s Gun", wait: REFRESH_WAIT
    assert_text "The detail pays off later."
    assignment = @scene.scene_tropes.find_by!(trope_slug: "chekhovs-gun")
    assert_equal "The detail pays off later.", assignment.context_note

    click_row_menu_action find(".entity-list .entity-row", text: "Chekhov’s Gun"), "Edit trope"
    within ".modal.show" do
      assert_field "Context note", with: "The detail pays off later."
      assert_equal "Chekhov’s Gun", selected_trope_text
      fill_in "Context note", with: "The planted detail returns in the final scene."
      click_button "Save trope"
    end

    assert_selector ".entity-row", text: "The planted detail returns in the final scene.", wait: REFRESH_WAIT
    assert_equal "The planted detail returns in the final scene.", assignment.reload.context_note

    click_row_menu_action find(".entity-list .entity-row", text: "Chekhov’s Gun"), "Remove",
      confirm: "Remove Chekhov’s Gun from Scene one?"

    assert_no_selector ".entity-row", text: "Chekhov’s Gun"
    assert_nil SceneTrope.find_by(id: assignment.id)
    # Removing the assignment never removes the shared catalogue reference.
    assert TropeCatalog.find("chekhovs-gun")
  end

  test "a duplicate reference is refused in the modal, which stays open" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_scene_tropes_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    click_button "Add trope"
    within ".modal.show" do
      choose_trope "Red Herring", query: "red"
      fill_in "Context note", with: "Again"
      click_button "Save trope"

      assert_selector "[data-modal-form-target='errors'] li", text: "Trope has already been taken"
      assert_selector "select#scene_trope_trope_slug[aria-invalid='true']"
      assert_field "Context note", with: "Again"
    end
    assert_selector ".modal.show"
    assert_equal 1, @scene.scene_tropes.count
  end

  test "saving without choosing a reference is explained in the modal" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_scene_tropes_path(universe_slug: @universe.slug, story_id: @story, scene_id: @scene)

    click_button "Add trope"
    within ".modal.show" do
      click_button "Save trope"

      assert_selector "[data-modal-form-target='errors'] li", text: "Trope can't be blank"
      assert_selector "select#scene_trope_trope_slug[aria-invalid='true']"
    end
    assert_selector ".modal.show"
    assert_equal 1, @scene.scene_tropes.count
  end

  test "a read-only member sees the tab without any control" do
    owner = users(:user_one)
    reader = users(:user_two)
    private_universe = Universe.create!(owner: owner, name: "Private tropes", slug: "private-tropes", private: true)
    story = Story.create!(universe: private_universe, name: "Private story")
    scene = story.scenes.create!(name: "Private scene")
    scene.scene_tropes.create!(trope_slug: "found-family", context_note: "The crew builds trust.")
    UniverseMembership.create!(universe: private_universe, user: reader, access_level: :read)

    sign_in_via_form(reader)
    visit universe_story_scene_scene_tropes_path(universe_slug: private_universe.slug, story_id: story, scene_id: scene)

    assert_selector ".entity-row", text: "Found Family"
    assert_text "The crew builds trust."
    assert_no_button "Add trope"
    assert_no_selector "[data-controller='modal-form']"
  end

  private
    # Tom Select hides the native select and renders its own search control, so a
    # choice is made where the reader makes it: type a narrowing query, then click
    # the matching option.
    def choose_trope(name, query: name)
      find(".ts-control").click
      find(".ts-control input").set(query)
      find(".ts-dropdown .option", text: name).click
    end

    # The item Tom Select is showing for the single select. The native select is
    # hidden, so its selected option cannot be read through Capybara's field
    # finder; the visible item is what the author is checking.
    def selected_trope_text
      find(".ts-control .item").text
    end
end
