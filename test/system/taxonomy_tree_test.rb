require "application_system_test_case"

class TaxonomyTreeTest < ApplicationSystemTestCase
  test "taxonomy names are text, parent options refresh, and counts update" do
    user = users(:user_one)
    universe = universes(:universe_one)
    hostile_name = "</option><img data-taxonomy-xss=\"parent-option\" src=x><option>Probe"

    sign_in_via_form(user)
    visit universe_character_tags_path(universe_slug: universe.slug)
    assert_stimulus_loaded

    assert_selector "h1", text: "Character tags"
    click_button "Add character tag"
    within ".taxonomy-new" do
      find("input[name='name']").set(hostile_name)
      click_button "Save"
    end
    assert_selector ".taxonomy-name-trigger", text: hostile_name
    assert_no_selector "img[data-taxonomy-xss]"
    within ".page-header" do
      assert_selector ".badge", text: "3"
    end

    other = character_tags(:character_tag_two)
    within "li[data-node-id='#{other.id}']" do
      find("button[aria-expanded='false']").click
      click_button "Edit"
    end
    within ".modal.show" do
      assert_selector "option", text: hostile_name
      assert_no_selector "img[data-taxonomy-xss]"
      fill_in "Description", with: "Updated from the modal"
      click_button "Save changes"
    end
    assert_selector "li[data-node-id='#{other.id}'] .entity-description", text: "Updated from the modal"
  end

  test "inline rename updates the serialized parent options" do
    user = users(:user_one)
    universe = universes(:universe_one)
    tag = character_tags(:character_tag_one)

    sign_in_via_form(user)
    visit universe_character_tags_path(universe_slug: universe.slug)
    assert_stimulus_loaded

    within "li[data-node-id='#{tag.id}'] > .taxonomy-row" do
      find("button.taxonomy-name-trigger").click
      find("form.taxonomy-update-form input[name='name']").set("Renamed browser tag")
      click_button "Save"
    end

    assert_selector "button.taxonomy-name-trigger", text: "Renamed browser tag"
    other = character_tags(:character_tag_two)
    within "li[data-node-id='#{other.id}']" do
      find("button[aria-expanded='false']").click
      click_button "Edit"
    end
    within ".modal.show" do
      assert_selector "option", text: "Renamed browser tag"
      assert_no_selector "option", text: "Character tag one"
      click_button "Cancel"
    end
  end

  test "root insertion uses the list boundary and the row menu moves items" do
    user = users(:user_one)
    universe = universes(:universe_one)
    story = stories(:story_one)
    root_a = sections(:section_one)
    child = sections(:section_two)
    root_b = Section.create!(story: story, name: "Root B", position: 1)
    root_a.update_column(:position, 0)
    child.update_column(:position, 0)

    sign_in_via_form(user)
    visit universe_story_sections_path(universe_slug: universe.slug, story_id: story)
    assert_stimulus_loaded

    find(".taxonomy-separator[data-parent-id=''][data-position='1'] button").click
    within ".taxonomy-new" do
      find("input[name='name']").set("Boundary root")
      click_button "Save"
    end

    assert_selector "button.taxonomy-name-trigger", text: "Boundary root"
    assert_equal [ "Section one", "Boundary root", "Root B" ], all("ul.taxonomy-list[data-drop-parent-id=''] > .taxonomy-node").map { |node| node[:"data-name"] }

    # Move up/down live in the row menu, and the boundary state is a disabled
    # menu item rather than a missing button. The menu is collapsed here, so the
    # items are asserted as present in the DOM rather than as visible.
    within "li[data-node-id='#{root_a.id}'] > .taxonomy-row" do
      assert_selector "[data-taxonomy-action='move-up'][disabled]", visible: :all
      assert_selector "[data-taxonomy-action='move-down']:not([disabled])", visible: :all
      find("button[aria-expanded='false']").click
      click_button "Move down"
    end

    assert_selector "li[data-name='Section one'] [data-taxonomy-action='move-up']:not([disabled])", visible: :all
    assert_equal [ "Boundary root", "Section one", "Root B" ], all("ul.taxonomy-list[data-drop-parent-id=''] > .taxonomy-node").map { |node| node[:"data-name"] }
  end

  test "the row menu holds every mutation and the name alone starts a rename" do
    user = users(:user_one)
    universe = universes(:universe_one)
    tag = character_tags(:character_tag_one)

    sign_in_via_form(user)
    visit universe_character_tags_path(universe_slug: universe.slug)

    within "li[data-node-id='#{tag.id}'] > .taxonomy-row" do
      # The row carries the name and the Details link only: the plus sign and the
      # move arrows are not row buttons any more.
      assert_selector "button.taxonomy-name-trigger"
      assert_no_selector "button[title='Add child']"
      assert_no_selector "button[title='Move up']"
      assert_no_selector "button[title='Move down']"
      find("button[aria-expanded='false']").click

      within ".dropdown-menu.show" do
        assert_text "Add child"
        assert_text "Insert before"
        assert_text "Insert after"
        assert_text "Move up"
        assert_text "Move down"
        assert_text "Edit"
        assert_text "Delete"
      end
    end
  end

  test "Add child from the row menu creates a nested record" do
    user = users(:user_one)
    universe = universes(:universe_one)
    tag = character_tags(:character_tag_one)

    sign_in_via_form(user)
    visit universe_character_tags_path(universe_slug: universe.slug)
    assert_stimulus_loaded

    within "li[data-node-id='#{tag.id}'] > .taxonomy-row" do
      find("button[aria-expanded='false']").click
      click_button "Add child"
    end

    within ".taxonomy-new" do
      find("input[name='name']").set("Child from the menu")
      click_button "Save"
    end

    # The create is a fetch followed by a same-URL refresh, so wait for the
    # refreshed row before reading the database.
    assert_selector "li[data-node-id='#{tag.id}'] .taxonomy-name-trigger", text: "Child from the menu"
    child = CharacterTag.find_by(name: "Child from the menu")
    assert_not_nil child
    assert_equal tag.id, child.parent_id
  end

  test "renaming keeps the element's tags" do
    user = users(:user_one)
    universe = universes(:universe_one)
    story = stories(:story_one)
    section = sections(:section_one)

    sign_in_via_form(user)
    visit universe_story_sections_path(universe_slug: universe.slug, story_id: story)
    assert_stimulus_loaded

    within "li[data-node-id='#{section.id}'] > .taxonomy-row" do
      assert_selector ".taxonomy-tag", text: "Section tag one"
      find("button.taxonomy-name-trigger").click
      find("form.taxonomy-update-form input[name='name']").set("Renamed section")
      click_button "Save"
    end

    within "li[data-node-id='#{section.id}'] > .taxonomy-row" do
      assert_selector ".taxonomy-tag", text: "Section tag one"
    end

    # The modal editor sends the whole record, so a rename that only changes the
    # description must not clear the assignment either.
    within "li[data-node-id='#{section.id}'] > .taxonomy-row" do
      find("button[aria-expanded='false']").click
      click_button "Edit"
    end
    within ".modal.show" do
      fill_in "Description", with: "Described from the modal"
      click_button "Save changes"
    end

    within "li[data-node-id='#{section.id}'] > .taxonomy-row" do
      assert_selector ".taxonomy-tag", text: "Section tag one"
      assert_selector ".entity-description", text: "Described from the modal"
    end
  end

  test "new taxonomy nodes can be renamed with the keyboard" do
    user = users(:user_one)
    universe = universes(:universe_one)

    sign_in_via_form(user)
    visit universe_character_tags_path(universe_slug: universe.slug)
    assert_stimulus_loaded
    click_button "Add character tag"
    within ".taxonomy-new" do
      find("input[name='name']").set("Keyboard tag")
      click_button "Save"
    end

    trigger = find("button.taxonomy-name-trigger", text: "Keyboard tag")
    trigger.send_keys(" ")
    assert_selector "form.taxonomy-update-form input[name='name']"
  end

  test "cancelling a new root restores the empty state" do
    user = users(:user_one)
    universe = Universe.create!(owner: user, name: "Empty taxonomy browser universe", slug: "empty-taxonomy-browser")

    sign_in_via_form(user)
    visit universe_character_tags_path(universe_slug: universe.slug)
    assert_stimulus_loaded
    assert_selector "[data-taxonomy-tree-empty]"

    click_button "Add character tag"
    within ".taxonomy-new" do
      click_button "Cancel"
    end

    assert_selector "[data-taxonomy-tree-empty]"
    assert_no_selector ".taxonomy-new"
  end

  test "touch-sized taxonomy controls remain available without hover" do
    user = users(:user_one)
    universe = universes(:universe_one)

    sign_in_via_form(user)
    page.current_window.resize_to(390, 844)
    visit universe_character_tags_path(universe_slug: universe.slug)
    assert_stimulus_loaded

    assert_selector ".taxonomy-separator-add", visible: :visible
    # Row mutations moved into the overflow menu, so the menu toggle is the row
    # control that must be visible without hover.
    assert_selector ".taxonomy-actions .dropdown-toggle", visible: :visible
  end
end
