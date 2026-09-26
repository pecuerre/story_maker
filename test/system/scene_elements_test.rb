require "application_system_test_case"

# Scene Elements are edited through the shared modal editor, so what a browser
# has to prove is the interaction the request suite cannot: the modal opens with
# the values the server stored, a rejected save stays open and explains itself in
# the modal, a Dialogue reveals its speaker picker only for Dialogue, and a
# successful mutation refreshes the list and its counts from one server render.
class SceneElementsTest < ApplicationSystemTestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
  end

  test "a writer creates, reorders, edits, and deletes a narration element" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    assert_selector ".scene-elements .badge[aria-label='4 elements']"
    assert_element_titles [ "The hollow tree", "Michael teaches the waltz", "The adults argue", "Interlude" ]

    open_element_editor("Add element") do
      assert_selector ".modal-title", text: "Add element"
      fill_in "Title", with: "The rain starts"
      fill_in "Content", with: "It starts without thunder and does not stop for an hour."
      click_button "Save element"
    end

    assert_element_titles [ "The hollow tree", "Michael teaches the waltz", "The adults argue", "Interlude", "The rain starts" ]
    assert_selector ".scene-elements .badge[aria-label='5 elements']", wait: REFRESH_WAIT

    move_element "The rain starts", "up"
    assert_element_titles [ "The hollow tree", "Michael teaches the waltz", "The adults argue", "The rain starts", "Interlude" ]

    # Moving the same element twice must reorder, never duplicate or drop a row.
    move_element "The rain starts", "up"
    assert_element_titles [ "The hollow tree", "Michael teaches the waltz", "The rain starts", "The adults argue", "Interlude" ]

    within ".scene-elements" do
      find(".entity-row", text: "The rain starts").find(".dropdown-toggle").click
      click_button "Edit"
    end
    within ".modal.show" do
      assert_selector ".modal-title", text: "Edit element"
      assert_field "Title", with: "The rain starts"
      assert_field "Content", with: "It starts without thunder and does not stop for an hour."
      fill_in "Content", with: "Edited from the browser."
      click_button "Save element"
    end

    assert_text "Edited from the browser.", wait: REFRESH_WAIT
    assert_equal 5, @scene.scene_elements.count

    within ".scene-elements" do
      find(".entity-row", text: "The rain starts").find(".dropdown-toggle").click
      accept_confirm("Delete “The rain starts”?") { click_button "Delete" }
    end

    assert_element_titles [ "The hollow tree", "Michael teaches the waltz", "The adults argue", "Interlude" ]
    assert_selector ".scene-elements .badge[aria-label='4 elements']"
  end

  test "a dialogue reveals its speaker picker and keeps every selected speaker" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    click_button "Add element"
    within ".modal.show" do
      # Narration has no speakers, so the picker starts hidden.
      assert_no_selector "[data-scene-element-form-target='speakers']", visible: :visible

      select "Dialogue", from: "Element type"
      assert_selector "[data-scene-element-form-target='speakers']", visible: :visible
      assert_text "A spoken block. Name everyone who speaks in it."

      fill_in "Title", with: "A kitchen argument"
      fill_in "Content", with: "You knew. I knew nothing."
      select "Character one", from: "Speakers"
      select "Character two", from: "Speakers"
      click_button "Save element"
    end

    within ".scene-elements" do
      row = find(".entity-row", text: "A kitchen argument", wait: REFRESH_WAIT)
      assert_text "Dialogue"
      assert_text "Character one and Character two speak in this block"
    end

    # Reopening the editor brings the stored kind and speakers back, which is the
    # part a request test cannot see.
    within ".scene-elements" do
      find(".entity-row", text: "A kitchen argument").find(".dropdown-toggle").click
      click_button "Edit"
    end
    within ".modal.show" do
      assert_field "Element type", with: "dialogue"
      assert_equal [ "Character one", "Character two" ], selected_speakers
    end
  end

  test "a dialogue with no speaker is refused in the modal, which stays open" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    click_button "Add element"
    within ".modal.show" do
      select "Dialogue", from: "Element type"
      fill_in "Title", with: "Nobody speaks"
      click_button "Save element"

      # The server's own message is rendered in the modal and on the control, the
      # entered values survive, and nothing was written.
      assert_selector "[data-modal-form-target='errors'] .alert-danger", text: "The change could not be saved"
      assert_selector "[data-modal-form-target='errors'] li", text: "Speakers is required for a dialogue element"
      assert_selector "select#scene_element_character_ids[aria-invalid='true']"
      assert_field "Title", with: "Nobody speaks"
    end
    # A rejected save must not close the modal.
    assert_selector ".modal.show"
    assert_equal 4, @scene.scene_elements.count
  end

  test "narration with speakers needs the explicit confirmation before it saves" do
    element = scene_elements(:dialogue_one)

    sign_in_via_form(users(:user_one))
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    within ".scene-elements" do
      find(".entity-row", text: element.name).find(".dropdown-toggle").click
      click_button "Edit"
    end

    within ".modal.show" do
      assert_selector "[data-scene-element-form-target='removeSpeakers']", visible: :all
      select "Narration", from: "Element type"
      assert_selector "[data-scene-element-form-target='removeSpeakers']", visible: :visible
      check "Remove the speakers and make this narration"
      click_button "Save element"
    end

    assert_selector ".scene-elements .entity-row", text: element.name, wait: REFRESH_WAIT
    assert_empty element.reload.characters
    assert_equal SceneElement::NARRATION, element.kind
  end

  test "a read-only member sees the element list without a single control" do
    owner = users(:user_one)
    reader = users(:user_two)
    private_universe = Universe.create!(owner: owner, name: "Private elements", slug: "private-elements", private: true)
    story = Story.create!(universe: private_universe, name: "Private story")
    scene = story.scenes.create!(name: "Private scene")
    scene.scene_elements.create!(name: "A beat", kind: "narration", body: "Readable prose.")
    UniverseMembership.create!(universe: private_universe, user: reader, access_level: :read)

    sign_in_via_form(reader)
    visit universe_story_scene_path(universe_slug: private_universe.slug, story_id: story, id: scene)

    assert_selector ".scene-elements .entity-row", text: "A beat"
    assert_text "Readable prose."
    assert_no_button "Add element"
    assert_no_selector ".scene-elements [data-action='modal-form#move']"
    assert_no_selector ".scene-elements [data-action='modal-form#destroy']"
    assert_no_selector ".scene-elements .dropdown.row-actions"
  end

  private
    def open_element_editor(title)
      click_button title
      within ".modal.show" do
        yield
      end
    end

    # A successful mutation ends in a same-URL Turbo visit, so an immediate read
    # can still see the previous render. Poll until the list settles.
    def assert_element_titles(expected)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
      actual = element_titles
      while actual != expected && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        sleep 0.1
        actual = element_titles
      end

      assert_equal expected, actual
    end

    def element_titles
      page.evaluate_script(
        "Array.from(document.querySelectorAll('.scene-elements .entity-title')).map(node => node.textContent.trim())"
      )
    rescue Selenium::WebDriver::Error::JavascriptError, Selenium::WebDriver::Error::NoSuchWindowError
      nil
    end

    def selected_speakers
      page.evaluate_script(
        "Array.from(document.querySelectorAll('#scene_element_character_ids option:checked'))" \
        ".map(option => option.textContent.trim())"
      )
    end

    def move_element(title, direction)
      within ".scene-elements" do
        find(".entity-row", text: title).find("button[data-modal-form-direction='#{direction}']").click
      end
      # The move refreshes the page from the server; the caller waits for the
      # resulting order.
      assert_selector ".scene-elements .entity-row"
    end
end
