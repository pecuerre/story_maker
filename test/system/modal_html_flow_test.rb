require "application_system_test_case"

# Browser regressions for the two modal workspaces that keep the HTML
# redirect/re-render flow (relations and ownerships). They are the counterpart of
# `modal_json_flow_test.rb`: the editor opens and pre-fills the same way, but the
# controller re-renders the whole index when it refuses a submission. That means
# the reason and the entered values have to survive that re-render, which is what
# these tests pin.
class ModalHtmlFlowTest < ApplicationSystemTestCase
  setup do
    @user = users(:user_one)
    @universe = universes(:universe_one)
    @character_one = characters(:character_one)
    @character_two = characters(:character_two)
  end

  test "a rejected relation states the reason and reopens with the entered values" do
    sign_in_via_form(@user)
    visit universe_relations_path(universe_slug: @universe.slug)
    assert_stimulus_loaded
    before = @universe.relations.count

    click_button "Add relation"
    within ".modal.show" do
      select @character_one.name, from: "Character 1"
      # The second character is left unset: the select is required, so the browser
      # is the one that blocks this submission, not the server. Drop the attribute
      # to reach the model's own rejection.
      execute_script(%(document.querySelector(".modal.show select[name='relation[character2_id]']").removeAttribute("required")))
      fill_in "Description", with: "Kept for another try"
      click_button "Save relation"
    end

    # The submission re-renders the index, so the reason is stated on the page the
    # author lands on and nothing was created.
    assert_selector ".alert-danger[role=alert]", text: "prevented this relation from being saved"
    assert_no_selector ".modal.show"
    assert_equal before, @universe.relations.count

    # Reopening the editor keeps the rejected entry, so the author can finish it.
    click_button "Add relation"
    within ".modal.show" do
      assert_selector ".alert-danger[role=alert]", text: "prevented this relation from being saved"
      assert_field "Description", with: "Kept for another try"
      select @character_one.name, from: "Character 1"
      select @character_two.name, from: "Character 2"
      click_button "Save relation"
    end

    assert_selector ".entity-row .entity-description", text: "Kept for another try", wait: REFRESH_WAIT
    assert_equal before + 1, @universe.relations.count
    assert_no_selector ".alert-danger[role=alert]"
  end

  test "an ownership can be created in the modal and the row and count follow" do
    sign_in_via_form(@user)
    visit universe_ownerships_path(universe_slug: @universe.slug)
    assert_stimulus_loaded
    before = @universe.ownerships.count

    click_button "Add ownership"
    within ".modal.show" do
      select items(:item_two).name, from: "Item"
      select @character_two.name, from: "Character"
      fill_in "Description", with: "Held on loan"
      click_button "Save ownership"
    end

    assert_selector ".entity-row .entity-description", text: "Held on loan", wait: REFRESH_WAIT
    within ".page-header" do
      assert_selector ".badge", text: (before + 1).to_s
    end
    assert_equal before + 1, @universe.ownerships.count
  end

  test "a named relation and its stored seconds survive an edit in the browser" do
    # Both halves of quirk 30 need a browser to be certain about: a `datetime-local`
    # given a value with seconds only keeps them if the control is stepped for
    # them, and the modal only pre-fills from the serialized record the row's
    # trigger carries. The request tests assert what the page ships; this asserts
    # that the browser keeps it.
    # Its own characters, so the row's visible endpoint pairing identifies it:
    # the row title is the two endpoints, not `display_string`, so the name is
    # asserted through the editor and the record's own page instead.
    martha = @universe.characters.create!(name: "Martha")
    ulrich = @universe.characters.create!(name: "Ulrich")
    relation = Relation.create!(universe: @universe, character1: martha, character2: ulrich,
      name: "Marriage of convenience", from_date: Time.utc(2024, 1, 1, 10, 0, 30))

    sign_in_via_form(@user)
    visit universe_relations_path(universe_slug: @universe.slug)
    assert_stimulus_loaded

    find(".entity-row", text: "Martha").find(".dropdown-toggle").click
    click_button "Edit"

    within ".modal.show" do
      # The name came back from the serialized record, not from a stale row.
      assert_field "Name", with: "Marriage of convenience"
      # The second is still there after the modal opened, which is the whole point
      # of `step: 1`: a whole-minute control drops it the moment it is written to.
      assert_equal "2024-01-01T10:00:30", find("input[name='relation[from_date]']").value

      fill_in "Description", with: "Edited"
      click_button "Save relation"
    end

    assert_selector ".alert-danger[role=alert]", count: 0, wait: REFRESH_WAIT
    relation.reload
    assert_equal "Marriage of convenience", relation.name
    assert_equal "Marriage of convenience", relation.display_string
    assert_equal Time.utc(2024, 1, 1, 10, 0, 30), relation.from_date
  end

  test "clearing a name in the browser keeps the record's address" do
    # Its own characters, for the same reason the other case gives itself some:
    # the row title is the endpoint pairing, so that text is what identifies it.
    hannah = @universe.characters.create!(name: "Hannah")
    jonas = @universe.characters.create!(name: "Jonas")
    relation = Relation.create!(universe: @universe, character1: hannah, character2: jonas,
      name: "Marriage of convenience")
    address = relation.slug

    sign_in_via_form(@user)
    visit universe_relations_path(universe_slug: @universe.slug)
    assert_stimulus_loaded

    find(".entity-row", text: "Hannah").find(".dropdown-toggle").click
    click_button "Edit"

    within ".modal.show" do
      assert_field "Name", with: "Marriage of convenience"
      fill_in "Name", with: ""
      click_button "Save relation"
    end

    assert_selector ".alert-danger[role=alert]", count: 0, wait: REFRESH_WAIT
    relation.reload
    # The name is cleared and the endpoints become the label again, but the slug the
    # record already had is its address and does not change underneath it.
    assert_nil relation.name
    assert_equal address, relation.slug
    assert_equal "Hannah → Jonas", relation.display_string
  end

  test "the row actions and the editor stay usable at a narrow viewport" do
    sign_in_via_form(@user)
    page.current_window.resize_to(390, 844)
    visit universe_relations_path(universe_slug: @universe.slug)
    assert_stimulus_loaded
    Relation.create!(universe: @universe, character1: @character_one, character2: @character_two, description: "A relation with a long description that has to wrap in a narrow list")
    visit universe_relations_path(universe_slug: @universe.slug)

    within ".list-group-item", text: "A relation with a long description" do
      assert_selector "a.details-link", text: "Details", visible: :visible
      assert_selector "button.dropdown-toggle", visible: :visible
    end
    click_button "Add relation"
    within ".modal.show" do
      assert_selector "select[name='relation[character1_id]']", visible: :visible
      assert_selector "input[type='submit']", visible: :visible
    end
  end
end
