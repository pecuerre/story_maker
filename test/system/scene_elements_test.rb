require "application_system_test_case"

# Scene Elements are edited through the shared modal editor, so what a browser
# has to prove is the interaction the request suite cannot: the modal opens with
# the values the server stored, a rejected save stays open and explains itself in
# the modal, a Dialogue hides Content in favour of its turns, and a successful
# mutation refreshes the list and its counts from one server render. The writing
# loop adds the parts only a browser has: a visible Edit control, the discard
# guard's two answers, mention cues surviving an edit, the draft alert a
# remembered save lands on, and the full-screen dialog a phone gets.
class SceneElementsTest < ApplicationSystemTestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
  end

  teardown do
    # One case narrows the window to a phone to check the full-screen editor;
    # Capybara reuses one browser for the whole process, so the size goes back.
    page.driver.browser.manage.window.resize_to(1400, 1400) if page.driver.browser
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

    click_element_edit("The rain starts")
    within ".modal.show" do
      assert_selector ".modal-title", text: "Edit element"
      assert_field "Title", with: "The rain starts"
      assert_field "Content", with: "It starts without thunder and does not stop for an hour."
      fill_in "Content", with: "Edited from the browser."
      click_button "Save element"
    end

    assert_text "Edited from the browser.", wait: REFRESH_WAIT
    assert_equal 5, @scene.scene_elements.count

    click_row_menu_action find(".scene-elements .entity-row", text: "The rain starts"), "Delete",
      confirm: "Delete “The rain starts”?"

    assert_element_titles [ "The hollow tree", "Michael teaches the waltz", "The adults argue", "Interlude" ]
    assert_selector ".scene-elements .badge[aria-label='4 elements']"
  end

  test "a dialogue hides Content and starts with the first-turn prompt" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    click_button "Add element"
    within ".modal.show" do
      # Narration keeps its prose in Content; a Dialogue keeps it in turns.
      assert_selector "[data-scene-element-form-target='body']", visible: :visible

      select "Dialogue", from: "Scene element type"
      assert_no_selector "[data-scene-element-form-target='body']", visible: :visible
      assert_no_selector "[data-scene-turns-target='entryFields']", visible: :visible
      assert_text "A spoken block, written as ordered lines."
      assert_selector "[data-scene-turns-target='saveFirst']", visible: :visible
      assert_no_button "Add turn"

      fill_in "Title", with: "A kitchen argument"
      click_button "Save element"
    end

    within ".scene-elements" do
      find(".entity-row", text: "A kitchen argument", wait: REFRESH_WAIT)
      assert_text "Dialogue"
      assert_text "0 lines"
    end

    # Reopening the editor brings the stored kind back and still hides Content,
    # which is the part a request test cannot see.
    click_element_edit("A kitchen argument")
    within ".modal.show" do
      assert_field "Scene element type", with: "dialogue"
      assert_no_selector "[data-scene-element-form-target='body']", visible: :visible
      assert_selector "[data-scene-turns-target='emptyState']", visible: :visible
    end
  end

  test "a saved dialogue supports ordered turns, editing, and move controls in its element modal" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    click_button "Add element"
    within ".modal.show" do
      select "Dialogue", from: "Scene element type"
      fill_in "Title", with: "A two-line exchange"
      click_button "Save element"
    end

    click_element_edit("A two-line exchange")
    within ".modal.show" do
      assert_selector "[data-scene-turns-target='emptyState']", visible: :visible
      assert_selector "[data-scene-turns-target='saveFirst']", visible: :hidden
      assert_selector "[data-scene-turns-target='entryFields']", visible: :visible
      assert_field "Speaker", with: ""

      select "Character one", from: "Speaker"
      fill_in "Line", with: "First line."
      fill_in "Delivery note", with: "quietly"
      click_button "Add turn"

      # Adding a line keeps the editor open and appends the saved row; staying
      # inside the still-present modal is what proves it did not close.
      assert_selector ".turn-row", count: 1
      assert_equal [ "First line." ], turn_lines

      select "Character two", from: "Speaker"
      fill_in "Line", with: "Second line."
      click_button "Add turn"
      assert_selector ".turn-row", count: 2
      assert_equal [ "First line.", "Second line." ], turn_lines

      first_row = find(".turn-row", text: "First line.")
      first_row.find("button[data-action='scene-turns#edit']").click
      first_row.find("select[name='speaker_id']").select("Character two")
      first_row.find("textarea[name='body']").set("Edited first line.")
      first_row.find("input[name='parenthetical']").set("firmly")
      first_row.find("button[data-action='scene-turns#save']").click
    end
    assert_no_selector ".modal.show", wait: REFRESH_WAIT

    click_element_edit("A two-line exchange")
    within ".modal.show" do
      assert_selector ".turn-row", text: /Character two:\s+Edited first line\.\s+\(firmly\)/
      find(".turn-row", text: "Second line.").find("button[data-modal-form-direction='up']").click
    end
    assert_no_selector ".modal.show", wait: REFRESH_WAIT

    click_element_edit("A two-line exchange")
    within ".modal.show" do
      assert_equal [ "Second line.", "Edited first line." ], turn_lines
      assert_selector ".turn-row", text: /Character two:\s+Edited first line\.\s+\(firmly\)/
    end
  end

  test "a non-character speaker keeps the tag in the line" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    click_button "Add element"
    within ".modal.show" do
      select "Dialogue", from: "Scene element type"
      fill_in "Title", with: "A voice through the door"
      click_button "Save element"
    end

    click_element_edit("A voice through the door")
    within ".modal.show" do
      select "Non-character speaker", from: "Speaker"
      fill_in "Line", with: "review-chair: Something"
      click_button "Add turn"

      assert_selector ".turn-row", count: 1
      assert_selector ".turn-row", text: /Non-character speaker:\s+review-chair: Something/
    end
  end

  test "narration stays blocked until its dialogue turns are removed" do
    element = scene_elements(:dialogue_one)

    sign_in_via_form(users(:user_one))
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    click_element_edit(element.name)

    within ".modal.show" do
      select "Narration", from: "Scene element type"
      assert_selector "[data-scene-element-form-target='body']", visible: :visible
      assert_no_selector "[data-scene-turns-target='entryFields']", visible: :visible
      click_button "Save element"
      assert_selector "[data-modal-form-target='errors'] li",
        text: "Scene element type cannot be Narration while dialogue turns remain"
      assert_selector ".turn-row", count: 2
    end

    # The server refuses to discard turns through a kind change. Once those
    # child rows are removed, the same edit is accepted.
    element.scene_dialogue_turns.destroy_all
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)
    click_element_edit(element.name)
    within ".modal.show" do
      select "Narration", from: "Scene element type"
      click_button "Save element"
    end

    assert_selector ".scene-elements .entity-row", text: element.name, wait: REFRESH_WAIT
    assert_equal SceneElement::NARRATION, element.reload.kind
  end

  test "dismissing an edited element asks before the prose is thrown away" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    click_element_edit("The hollow tree")
    within ".modal.show" do
      fill_in "Content", with: "A paragraph the writer does not want to lose."
      # The first Cancel keeps the editor and its text. The reader has to say yes
      # to lose a paragraph they have written.
      dismiss_confirm "Discard what you have written? It has not been saved." do
        click_button "Cancel"
      end
      assert_selector ".modal-title", text: "Edit element"
      assert_field "Content", with: "A paragraph the writer does not want to lose."

      accept_confirm "Discard what you have written? It has not been saved." do
        click_button "Cancel"
      end
    end

    assert_no_selector ".modal.show"
    assert_equal "Jonas wedges the box into the hollow of the oak and keeps his hand on it.",
      scene_elements(:narration_one).reload.body
    # The editor hands focus back to the control that opened it, so a keyboard
    # reader is on the row they were editing rather than on the page body.
    assert_selector ".scene-elements .entity-row button[data-action='modal-form#open']:focus"
  end

  test "an editor opened and closed without a change does not ask" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    click_element_edit("Interlude")
    within ".modal.show" do
      # Reading the stored values is not an edit: Cancel closes at once, with no
      # confirmation to click through.
      click_button "Cancel"
    end
    assert_no_selector ".modal.show"
  end

  test "editing an element keeps its prose mention cues" do
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    click_element_edit("The hollow tree")
    within ".modal.show" do
      fill_in "Content", with: "Character one waits under the oak."
      click_button "Save element"
    end

    row = find(".scene-elements .entity-row", text: "The hollow tree", wait: REFRESH_WAIT)
    within row do
      assert_selector "a.mention", text: "Character one"
    end
  end

  test "a remembered element create says it went to the draft" do
    @universe.update!(collaboration_mode: "wikipedia")
    sign_in_via_form(users(:user_one))
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    click_button "Add element"
    within ".modal.show" do
      fill_in "Title", with: "Remembered prose"
      fill_in "Content", with: "Not live until the draft is applied."
      click_button "Save element"
    end

    # The save is remembered rather than written, and the page says so in its own
    # flow: a JSON editor that only refreshed would leave Scene Details looking
    # exactly as it did before the writer typed.
    assert_selector ".draft-remembered", text: "New Scene element is in your draft", wait: REFRESH_WAIT
    assert_no_selector ".scene-elements .entity-title", text: "Remembered prose"
    assert_nil SceneElement.find_by(name: "Remembered prose")
  end

  test "the element editor uses the whole screen on a phone" do
    sign_in_via_form(users(:user_one))
    page.driver.browser.manage.window.resize_to(390, 844)
    visit universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)

    click_element_edit("The hollow tree")
    within ".modal.show" do
      # A full-screen dialog is what gives a phone's on-screen keyboard room to
      # open over a paragraph, rather than a centred dialog it covers whole.
      dialog = find(".modal-dialog")
      assert_operator dialog.evaluate_script("this.getBoundingClientRect().width"), :>, 350
      assert_operator dialog.evaluate_script("this.getBoundingClientRect().height"), :>, 500
    end
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

    # Opening a row's editor through the visible Edit control, which is how a
    # writer reaches it now that it is not a menu item.
    def click_element_edit(name)
      within find(".scene-elements .entity-row", text: name) do
        find("button[data-action='modal-form#open']", text: "Edit").click
      end
      assert_selector ".modal.show"
    end

    def turn_lines
      page.evaluate_script(
        "Array.from(document.querySelectorAll('.turn-row .turn-line')).map(node => node.textContent.trim())"
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
