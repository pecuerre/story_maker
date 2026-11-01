require "application_system_test_case"

# The Canon list is the flat list whose owner is optional, so the search area is
# covered in the browser: the text, canon-type, and owner controls must narrow
# the list, each choice must stay in the URL, and clearing them must restore the
# whole list. A request test can assert the rows a query returns; only the
# browser shows the controls a reader actually operates.
class CanonFilterTest < ApplicationSystemTestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
  end

  test "a writer narrows the canon list by text, canon type, and owner, then clears it" do
    sign_in_via_form(users(:user_one))
    visit universe_canon_rules_path(universe_slug: @universe.slug)
    assert_canon_names [ "Magic costs a memory", "The night crossing" ]

    # The row leads with the ledger id, so the list and a citation in prose use
    # the same label.
    assert_selector ".entity-row code.canon-rule-id", text: "K1"

    fill_in "canon_rule_filter_q", with: "memory"
    click_button "Filter canon rules"

    assert_current_path canon_rules_path(q: "memory")
    assert_canon_names [ "Magic costs a memory" ]
    assert_text "Showing 1 rule of 2 rules"
    assert_text "Search: “memory”"

    click_link "Clear filters"

    assert_current_path canon_rules_path
    assert_canon_names [ "Magic costs a memory", "The night crossing" ]

    select "Rule", from: "Canon type"
    click_button "Filter canon rules"

    assert_current_path canon_rules_path(canon_type: "rule")
    assert_canon_names [ "The night crossing" ]
    assert_text "Canon type: Rule"
  end

  test "the owner control narrows to one story's rules or to the universe-wide ones" do
    sign_in_via_form(users(:user_one))
    visit universe_canon_rules_path(universe_slug: @universe.slug)

    select @story.name, from: "Owned by"
    click_button "Filter canon rules"

    assert_current_path canon_rules_path(owner_story_id: @story.id)
    assert_canon_names [ "The night crossing" ]
    assert_text "Owned by: Story One"

    select "Whole universe", from: "Owned by"
    click_button "Filter canon rules"

    assert_current_path canon_rules_path(owner_story_id: "universe")
    assert_canon_names [ "Magic costs a memory" ]
  end

  test "a filter that matches nothing is not an empty universe" do
    sign_in_via_form(users(:user_one))
    visit universe_canon_rules_path(universe_slug: @universe.slug)

    fill_in "canon_rule_filter_q", with: "no such rule"
    click_button "Filter canon rules"

    assert_selector ".empty-title", text: "No canon rules match these filters"
    assert_selector ".empty-description", text: "Universe one has 2 rules, but none of them match"
    assert_text "Search: “no such rule”"
    assert_link "Clear filters"
  end

  private
    # The filter lives in the query string, so the expected path carries it.
    def canon_rules_path(**filter)
      universe_canon_rules_path(universe_slug: @universe.slug, **filter)
    end

    # Turbo re-renders the list after the redirect, so an immediate read can
    # still see the previous page. Poll until it settles.
    def assert_canon_names(expected)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
      actual = canon_names
      while actual != expected && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        sleep 0.1
        actual = canon_names
      end

      assert_equal expected, actual
    end

    def canon_names
      # Read the list in one shot: a Turbo re-render can detach element handles
      # between a query and a read, which is not what this assertion is about.
      page.evaluate_script(
        "Array.from(document.querySelectorAll('.entity-list .entity-title')).map(node => node.textContent.trim())"
      )
    rescue Selenium::WebDriver::Error::JavascriptError, Selenium::WebDriver::Error::NoSuchWindowError
      nil
    end
end
