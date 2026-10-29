require "application_system_test_case"

# The Universes index is the landing page: where a reader chooses a workspace.
# `test/controllers/universes_controller_test.rb` proves the counts, the
# authorization, and that nothing is recounted per row; what only a browser
# shows is that the counts and the recent-activity sentence render there, and
# that an open row menu is not clipped by the list.
class UniversesTest < ApplicationSystemTestCase
  test "the index shows each universe's contents and recent activity" do
    sign_in_via_form(users(:user_one))

    visit root_path

    within ".entity-list" do
      assert_selector ".entity-description", text: /2 stories/
      assert_selector ".entity-description", text: /17 entities/
      assert_selector ".entity-description", text: /1 story/
      assert_selector ".entity-description", text: /6 entities/
      assert_selector "time", count: 2
    end
  end

  test "opening a row's action menu leaves the list unclipped" do
    sign_in_via_form(users(:user_one))

    visit root_path

    row = find(".entity-row", text: universes(:universe_one).name)
    within row do
      find(".dropdown .dropdown-toggle").click
    end
    assert_selector ".dropdown-menu.show", visible: :visible

    # The list used to be a Bootstrap `.table-responsive` table, whose scrolling
    # wrapper turned the open menu into scrollbars on the list instead of a menu
    # painted over the page. `elementFromPoint` is what proves the menu is not
    # clipped: a point inside the menu's own box must hit the menu, not an
    # ancestor that scrolled it out of sight.
    menu_state = page.evaluate_script(<<~JS)
      (() => {
        const menu = document.querySelector(".dropdown-menu.show")
        const rect = menu.getBoundingClientRect()
        const hit = document.elementFromPoint(rect.left + rect.width / 2, rect.bottom - 4)
        return {
          menuInViewport: rect.top >= 0 && rect.bottom <= window.innerHeight,
          menuIsHit: menu.contains(hit)
        }
      })()
    JS

    assert menu_state["menuInViewport"], "the open menu should be inside the viewport"
    assert menu_state["menuIsHit"], "the open menu should not be clipped by a scrolling ancestor"
  end

  test "the universe action menu opens the permanent delete page" do
    universe = universes(:universe_one)
    sign_in_via_form(users(:user_one))

    visit root_path

    row = find(".entity-row", text: universe.name)
    click_row_menu_action(row, "Delete universe permanently")

    assert_current_path universe_purge_path(universe_slug: universe.slug)
    assert_selector ".alert-danger",
      text: /This is irreversible, please confirm that you understand what you are doing/
    assert_button "Delete this universe permanently", disabled: true
  end

  test "the owner deletes a universe permanently by typing its exact name" do
    universe = Universe.create!(owner: users(:user_one), name: "Eärendil, The Mariner!", slug: "earendil-mariner")
    sign_in_via_form(users(:user_one))

    visit edit_universe_path(universe)
    click_link "Delete this universe permanently"
    assert_current_path universe_purge_path(universe_slug: universe.slug)

    # The button is unavailable until the field carries the name exactly, and the
    # browser offers no saved value for the field.
    assert_button "Delete this universe permanently", disabled: true
    assert_equal "off", find_field("Type Eärendil, The Mariner! to confirm")[:autocomplete]

    fill_in "Type Eärendil, The Mariner! to confirm", with: "eärendil, the mariner!"
    assert_button "Delete this universe permanently", disabled: true

    fill_in "Type Eärendil, The Mariner! to confirm", with: "Eärendil The Mariner!"
    assert_button "Delete this universe permanently", disabled: true

    fill_in "Type Eärendil, The Mariner! to confirm", with: universe.name
    assert_button "Delete this universe permanently", disabled: false

    click_button "Delete this universe permanently"

    assert_current_path universes_path
    assert_selector ".alert-success", text: /Eärendil, The Mariner!.*permanently deleted/
    assert_no_selector ".entity-title", text: universe.name
    assert_not Universe.exists?(universe.id)
  end
end
