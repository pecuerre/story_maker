require "application_system_test_case"

# The Characters list is the first flat list a reader can narrow, and the first
# one they can reorder, so the search area is covered in the browser: the filter
# must narrow the list, the sort must reorder it without writing anything, both
# must stay in the URL, and both must be removable. A request test can assert the
# order the query returns; only the browser shows that choosing an order leaves
# the records themselves alone.
class CharacterFilterTest < ApplicationSystemTestCase
  # The width `application_system_test_case.rb` drives the browser at. Named here
  # so the teardown puts back the value the suite actually uses rather than a
  # number repeated from it.
  DEFAULT_WINDOW_SIZE = [ 1400, 1400 ].freeze
  setup do
    @universe = universes(:universe_one)
    # Both timestamps are set explicitly, because a save stamps `updated_at` for
    # itself and "recently edited first" is otherwise ordered by which fixture the
    # loader happened to write last.
    characters(:character_one).update!(created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 3, 1))
    characters(:character_two).update!(created_at: Time.utc(2026, 3, 1), updated_at: Time.utc(2026, 4, 1))
    characters(:character_three).update!(created_at: Time.utc(2026, 2, 1), updated_at: Time.utc(2026, 2, 1))
    @positions = @universe.characters.order(:id).pluck(:id, :position).to_h
  end

  teardown do
    # Capybara keeps one browser window for the whole process, so a test that
    # narrows it has to put it back or every test after this one runs narrow.
    page.driver.browser.manage.window.resize_to(*DEFAULT_WINDOW_SIZE) if page.driver.browser
  end

  test "a writer narrows the character list, sees it in the URL, and clears it" do
    characters(:character_one).update!(at_a_glance: "The keeper of the gate")

    sign_in_via_form(users(:user_one))
    visit universe_characters_path(universe_slug: @universe.slug)
    assert_character_names [ "Character one", "Character three", "Character two" ]

    # The top bar carries its own search field, so this filter is addressed by its
    # own id rather than by a label both fields answer to.
    fill_in "character_filter_q", with: "keeper"
    click_button "Filter characters"

    assert_current_path characters_path(q: "keeper")
    assert_character_names [ "Character one" ]
    assert_text "Showing 1 character of 3 characters"
    assert_text "Search: “keeper”"

    click_link "Clear filters"

    assert_current_path characters_path
    assert_character_names [ "Character one", "Character three", "Character two" ]
    assert_no_link "Clear filters"
  end

  test "choosing an order reorders the list and changes nothing on the records" do
    sign_in_via_form(users(:user_one))
    visit universe_characters_path(universe_slug: @universe.slug)

    select "Newest first", from: "Order"
    click_button "Filter characters"

    assert_current_path characters_path(sort: "created")
    assert_character_names [ "Character two", "Character three", "Character one" ]
    assert_text "Order: Newest first"

    # An order is a read. A sort that renumbered a position would contradict the
    # hierarchy the same workspace writes elsewhere.
    assert_equal @positions, @universe.characters.order(:id).pluck(:id, :position).to_h
  end

  test "a filter that matches nothing is not an empty universe" do
    sign_in_via_form(users(:user_one))
    visit universe_characters_path(universe_slug: @universe.slug)

    fill_in "character_filter_q", with: "no such character"
    click_button "Filter characters"

    assert_selector ".empty-title", text: "No characters match these filters"
    assert_selector ".empty-description", text: "Universe one has 3 characters, but none of them match"
    assert_text "Search: “no such character”"
    # The universe is not empty, so nothing here offers to add the first one.
    within ".empty-state" do
      click_link "Clear filters"
    end

    assert_character_names [ "Character one", "Character three", "Character two" ]
  end

  test "a guest filters with the keyboard alone at a narrow width" do
    # The search area is a form of inputs and selects, so a narrow viewport has to
    # fold it instead of widening the page.
    #
    # One test, one navigation: typing and pressing Enter submits the form, and a
    # second submit before that Turbo navigation has landed would race the page it
    # is replacing rather than test anything.
    page.driver.browser.manage.window.resize_to(420, 900)
    visit universe_characters_path(universe_slug: @universe.slug)
    assert_character_names [ "Character one", "Character three", "Character two" ]
    assert_no_selector "button[data-action='modal-form#open']"

    find("#character_filter_q").send_keys("character", :return)

    assert_current_path characters_path(q: "character")
    assert_character_names [ "Character one", "Character three", "Character two" ]
    assert_no_horizontal_overflow
  end

  test "a guest chooses an order at a narrow width" do
    page.driver.browser.manage.window.resize_to(420, 900)
    visit universe_characters_path(universe_slug: @universe.slug)

    # An order is a native select, which the keyboard already drives, so choosing
    # one needs no pointer beyond the control itself.
    select "Recently edited first", from: "Order"
    click_button "Filter characters"

    assert_current_path characters_path(sort: "updated")
    assert_character_names [ "Character two", "Character one", "Character three" ]
    assert_no_horizontal_overflow
  end

  private
    # The filter lives in the query string, so the expected path carries it.
    def characters_path(**filter)
      universe_characters_path(universe_slug: @universe.slug, **filter)
    end

    def assert_no_horizontal_overflow
      scroll_width, viewport_width = page.evaluate_script(
        "[document.documentElement.scrollWidth, window.innerWidth]"
      )

      assert_operator scroll_width, :<=, viewport_width + 1
    end

    # Turbo re-renders the list after a redirect, so an immediate read of the
    # order can still see the previous page. Poll until it settles.
    def assert_character_names(expected)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
      actual = character_names
      while actual != expected && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        sleep 0.1
        actual = character_names
      end

      assert_equal expected, actual
    end

    def character_names
      # Read the order in one shot: a Turbo re-render can detach element handles
      # between a query and a read, which is not what this assertion is about.
      page.evaluate_script(
        "Array.from(document.querySelectorAll('.entity-list .entity-title')).map(node => node.textContent.trim())"
      )
    rescue Selenium::WebDriver::Error::JavascriptError, Selenium::WebDriver::Error::NoSuchWindowError
      nil
    end
end
