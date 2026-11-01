require "application_system_test_case"

# An Item's profile is one Markdown description, edited through the flat list's
# shared modal. What only a browser can show is that the textarea exists, accepts
# Markdown, saves through the JSON mutation path, and that the details page
# renders its headings and links through the shared dialect.
class ItemDescriptionTest < ApplicationSystemTestCase
  test "an Item's Markdown description saves from the list editor and renders on its page" do
    user = users(:user_one)
    universe = universes(:universe_one)
    item = items(:item_one)

    sign_in_via_form(user)
    visit universe_items_path(universe_slug: universe.slug)
    assert_stimulus_loaded

    click_row_menu_action find(".entity-row", text: item.name), "Edit"
    within ".modal.show" do
      fill_in "Description", with: "## What it does\n\nOpens [[canon:K1]] and [[character:character-one]]."
      click_button "Save item"
    end

    assert_no_selector ".modal.show"
    item.reload
    assert_equal "## What it does\n\nOpens [[canon:K1]] and [[character:character-one]].", item.description

    visit universe_item_path(universe_slug: universe.slug, id: item)

    assert_selector ".detail-fact dt", text: /Description/i
    assert_selector ".detail-fact dd h2", text: "What it does"
    # A canon citation keeps its ledger id; a record reference is named by the
    # record it links to.
    assert_selector ".detail-fact dd a", text: "K1"
    assert_selector ".detail-fact dd a", text: "Character one"
    # The old structured profile answers are gone from the page.
    assert_no_selector ".detail-fact dt", text: /What it does/i
  end
end
