require "application_system_test_case"

# The top bar's two width facts that only a browser can show: the draft
# indicator stays visible below `lg`, where the navigation is collapsed, and a
# long Universe or Story name does not widen the bar at the `lg` breakpoint.
class NavbarLayoutTest < ApplicationSystemTestCase
  setup do
    @user = users(:user_one)
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @universe.update!(collaboration_mode: "wikipedia")
  end

  teardown do
    page.driver.browser.manage.window.resize_to(1400, 1400) if page.driver.browser
  end

  test "the draft indicator is visible below lg before the menu is opened" do
    sign_in_via_form(@user)
    page.driver.browser.manage.window.resize_to(720, 900)
    visit universe_characters_path(universe_slug: @universe.slug)

    # The collapsed navigation is closed, so the actions row inside it is not
    # visible. The indicator must still be on the first paint, beside the
    # toggler, rather than behind it.
    assert_no_selector ".navbar-collapse", visible: true
    within ".navbar-mobile-actions" do
      assert_selector ".draft-indicator", text: "Draft"
    end
    assert_no_selector ".navbar-actions .draft-indicator", visible: true

    within ".navbar-mobile-actions" do
      find(".draft-indicator").click
    end
    assert_current_path universe_drafts_path(universe_slug: @universe.slug), wait: REFRESH_WAIT
  end

  test "long scope names do not widen the navbar at the lg breakpoint" do
    @universe.update!(name: "The Meridian Archive of Unfinished Histories")
    @story.update!(name: "The Fifth Cabinet and the Ledger of Small Hours")

    sign_in_via_form(@user)
    page.driver.browser.manage.window.resize_to(992, 800)
    visit universe_story_path(universe_slug: @universe.slug, id: @story)

    # The names are still in the bar and its accessible text; the CSS truncates
    # them rather than letting the row grow.
    assert_selector ".navbar-context", text: @universe.name
    assert_selector ".navbar-context", text: @story.name

    measurements = page.evaluate_script(<<~JS)
      (function () {
        var navbar = document.querySelector(".navbar")
        var navItems = document.querySelectorAll(".navbar-nav .nav-item")
        var lastItem = navItems[navItems.length - 1]
        var search = document.querySelector(".navbar-search")
        return {
          scroll: navbar.scrollWidth,
          client: navbar.clientWidth,
          documentScroll: document.documentElement.scrollWidth,
          documentClient: document.documentElement.clientWidth,
          lastItemRight: lastItem.getBoundingClientRect().right,
          searchLeft: search.getBoundingClientRect().left
        }
      })()
    JS

    assert_operator measurements["scroll"], :<=, measurements["client"] + 1,
      "the navbar should not scroll horizontally: #{measurements.inspect}"
    assert_operator measurements["documentScroll"], :<=, measurements["documentClient"] + 1,
      "the page should not gain a horizontal scrollbar: #{measurements.inspect}"
    assert_operator measurements["lastItemRight"], :<=, measurements["searchLeft"] + 1,
      "the scope links and the search should not overlap: #{measurements.inspect}"
  end
end
