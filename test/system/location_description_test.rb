require "application_system_test_case"

# A Location's profile is one Markdown description, edited through the tree's
# browser-built modal. What only a browser can show is that the shared textarea
# exists, accepts Markdown, saves through the JSON mutation path, and that the
# details page renders its headings and links through the shared dialect.
class LocationDescriptionTest < ApplicationSystemTestCase
  test "a Location's Markdown description saves from the tree editor and renders on its page" do
    user = users(:user_one)
    universe = universes(:universe_one)
    location = locations(:location_one)

    sign_in_via_form(user)
    visit universe_locations_path(universe_slug: universe.slug)
    assert_stimulus_loaded

    click_row_menu_action "li[data-node-id='#{location.id}'] > .taxonomy-row", "Edit"
    within ".modal.show" do
      # A Location's editor is the wide dialog the flat-list record editors use.
      assert_selector ".modal-dialog.modal-lg"
      fill_in "Short summary", with: "A keep watched by [[character:character-one]]."
      fill_in "Description", with: "## History\n\nSee [[canon:K1]] and [[character:character-one]]."
      click_button "Save changes"
    end

    assert_no_selector ".modal.show"
    location.reload
    assert_equal "A keep watched by [[character:character-one]].", location.summary
    assert_equal "## History\n\nSee [[canon:K1]] and [[character:character-one]].", location.description

    # The tree row is the glance: the summary with its reference reduced to the
    # record's name, never the full Markdown description.
    assert_selector ".taxonomy-node[data-node-id='#{location.id}'] .entity-description",
      text: "A keep watched by Character one."

    visit universe_location_path(universe_slug: universe.slug, id: location)

    assert_selector ".page-description a", text: "Character one"
    assert_selector ".detail-fact dt", text: /Description/i
    assert_selector ".detail-fact dd h2", text: "History"
    # A canon citation keeps its ledger id; a record reference is named by the
    # record it links to.
    assert_selector ".detail-fact dd a", text: "K1"
    assert_selector ".detail-fact dd a", text: "Character one"
    # The old structured profile answers are gone from the page.
    assert_no_selector ".detail-fact dt", text: /Sensory: sight/i
  end
end
