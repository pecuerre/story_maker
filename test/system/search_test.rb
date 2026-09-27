require "application_system_test_case"

# The top-bar search box in a real browser.
#
# The request suite proves the JSON contract and the results page; what only a
# browser can show is the part a reader actually touches: that typing opens a
# panel, that the panel is reachable and usable from the keyboard, that it
# navigates, and that it is inside the bar at the width the bar collapses to.
#
# The engine is the test double (`SearchTestBackend`), because CI has no
# Meilisearch. What is under test is the box, not the engine.
class SearchTest < ApplicationSystemTestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
  end

  def stub_engine(hits: [ character_hit ], available: true)
    Search.backend = SearchTestBackend.new(hits: hits, available: available)
  end

  def character_hit(title: "Hannah", kind_label: "Character", body: "A mother who disappears")
    SearchTestBackend.document(
      id: "character-4", kind: "character", title: title,
      universe_id: @universe.id, body: body,
      url: universe_character_path(universe_slug: @universe.slug, id: 4)
    )
  end

  def command_hit
    { id: "characters", title: "Characters", subtitle: @universe.name,
      url: universe_characters_path(universe_slug: @universe.slug) }
  end

  def search_box
    find(".navbar-search-input", visible: :all)
  end

  test "typing opens a panel of results, and choosing one opens the record" do
    stub_engine
    sign_in_via_form(users(:user_one))
    visit universe_characters_path(universe_slug: @universe.slug)

    assert_no_selector "[data-search-target='results'] [role='option']"

    search_box.fill_in with: "hannah"
    assert_selector "[data-search-target='results'] [role='option']", text: "Hannah"
    # The scope travels with the request, so the dropdown asked inside this universe.
    assert_text "Character"
    assert_text @universe.name

    click_link "Hannah", match: :first

    assert_current_path universe_character_path(universe_slug: @universe.slug, id: 4)
  end

  test "commands and records are separate groups, commands first" do
    Search.backend = SearchTestBackend.new(hits: [ character_hit ])
    sign_in_via_form(users(:user_one))
    visit universe_characters_path(universe_slug: @universe.slug)

    search_box.fill_in with: "chara"

    assert_selector "[role='group'][aria-label='Go to'] [role='option']", text: "Characters"
    click_link "Characters", match: :first

    assert_current_path universe_characters_path(universe_slug: @universe.slug)
  end

  test "a reader drives the whole list from the keyboard and the caret stays put" do
    stub_engine
    sign_in_via_form(users(:user_one))
    visit universe_characters_path(universe_slug: @universe.slug)

    search_box.fill_in with: "hannah"
    assert_selector "[data-search-target='results'] [role='option']"

    search_box.send_keys(:arrow_down)
    active = find "[data-search-target='results'] [role='option'].active"
    assert_equal active["id"], search_box["aria-activedescendant"]
    assert_equal "true", active["aria-selected"]
    # Focus never left the input, so the reader can keep typing.
    assert_equal search_box.native.attribute("id"), page.evaluate_script("document.activeElement.id")

    search_box.send_keys(:enter)

    assert_current_path universe_character_path(universe_slug: @universe.slug, id: 4)
  end

  test "Escape closes the panel and hands the key back to the page" do
    stub_engine
    sign_in_via_form(users(:user_one))
    visit universe_characters_path(universe_slug: @universe.slug)

    search_box.fill_in with: "hannah"
    assert_selector "[data-search-target='results'] [role='option']"

    search_box.send_keys(:escape)

    assert_no_selector "[data-search-target='results'] [role='option']"
    assert_equal "false", search_box["aria-expanded"]
  end

  test "one character asks nothing, and the page still answers" do
    stub_engine
    sign_in_via_form(users(:user_one))
    visit universe_characters_path(universe_slug: @universe.slug)

    search_box.fill_in with: "h"

    assert_text "Type 1 more characters to search."

    # Submitting the form is the answer a reader without scripting gets, and it
    # has to work while the box is on the page. The scope is part of the
    # submission, because the dropdown is inside the form.
    search_box.send_keys(:enter)

    assert_current_path universe_search_path(universe_slug: @universe.slug, q: "h", scope: "universe")
    assert_text "Keep typing"
  end

  test "a search with no matches is said plainly, and the full page agrees" do
    Search.backend = SearchTestBackend.new(hits: [])
    sign_in_via_form(users(:user_one))
    visit universe_characters_path(universe_slug: @universe.slug)

    search_box.fill_in with: "zzzznotathing"
    assert_selector "[data-search-target='results'] [role='option'][aria-disabled='true']",
      text: "No matches"
    # Nothing to see, so nothing to open: a link to a page of no matches is not an
    # invitation.
    assert_no_link "See all results"

    search_box.send_keys(:enter)

    assert_current_path universe_search_path(universe_slug: @universe.slug,
      q: "zzzznotathing", scope: "universe")
    assert_text "Nothing matched"
  end

  test "an engine that is not there is stated, and the rest of the page still works" do
    stub_engine(available: false)
    sign_in_via_form(users(:user_one))
    visit universe_characters_path(universe_slug: @universe.slug)

    search_box.fill_in with: "hannah"
    assert_selector "[data-search-target='results'] [role='option']", text: "Search is not available"

    # The page the reader was on is untouched, and navigation still works.
    click_link "Characters"
    assert_current_path universe_characters_path(universe_slug: @universe.slug)
  end

  test "the scope dropdown narrows the search and the box keeps it" do
    stub_engine
    sign_in_via_form(users(:user_one))
    visit universe_story_scenes_path(universe_slug: @universe.slug, story_id: @story)

    # The box offers this universe by default, and this story because a story is
    # the one being read.
    within ".navbar-search" do
      assert_selector "select[name=scope] option[selected]", text: "This universe"
      assert_selector "select[name=scope] option:not([disabled])", text: "This story"
    end

    search_box.fill_in with: "hannah"
    assert_selector "[data-search-target='results'] [role='option']"

    within ".navbar-search" do
      find("select[name=scope]").select "characters"
    end
    assert_selector "[data-search-target='results'] [role='option']", text: "Hannah"
  end

  test "the box is reachable at the width the bar collapses to" do
    stub_engine
    sign_in_via_form(users(:user_one))
    visit universe_characters_path(universe_slug: @universe.slug)

    # A viewport left narrow by an earlier test would make this case pass for the
    # wrong reason, and would surface as a confusing failure in whichever test
    # happened to run next, so the width this case depends on is checked rather
    # than assumed.
    assert_equal 1400, page.current_window.size.first, "the bar was not wide to begin with"

    page.current_window.resize_to(420, 900)
    assert_no_selector ".navbar-search-input", visible: true

    # Below `lg` the bar is one collapsed menu, and the box is inside it like the
    # account menu is.
    find(".navbar-toggler").click
    assert_selector ".navbar-search-input", visible: true

    search_box.fill_in with: "hannah"
    assert_selector "[data-search-target='results'] [role='option']", text: "Hannah"
  ensure
    # Restored here rather than left to the next session, which may reuse this
    # window and so never apply its own configured size.
    page&.current_window&.resize_to(1400, 1400)
  end

  test "the results page states the scope and the count" do
    stub_engine(hits: [ character_hit, character_hit(title: "Hannah Kent") ])
    sign_in_via_form(users(:user_one))

    visit universe_search_path(universe_slug: @universe.slug, q: "hannah")

    assert_text "Searching"
    assert_text "This universe"
    assert_selector ".search-result", count: 2
    # The group title is uppercased by the stylesheet, so the count is matched
    # without regard to case rather than against the rendered capitalisation.
    assert_selector ".search-group-title", text: /2 matches/i
  end

  test "a guest can use the box on a public universe" do
    stub_engine
    visit universe_characters_path(universe_slug: @universe.slug)

    search_box.fill_in with: "hannah"

    assert_selector "[data-search-target='results'] [role='option']", text: "Hannah"
  end
end
