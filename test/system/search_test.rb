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
  # Whether the box is actually listening. Stimulus resolves each controller through
  # a dynamic `import()` and then connects it on a later turn of the router, so
  # "registered" and "connected" are two different moments and only the second one
  # means a keystroke will be heard. Optional chaining, because the application
  # itself is assigned by a module the page has to fetch first.
  SEARCH_CONTROLLER_CONNECTED_JS = <<~JS
    Boolean(window.Stimulus?.getControllerForElementAndIdentifier(
      document.querySelector(".navbar-search"), "search"))
  JS

  # How tall the panel's box is while the search is closed. The wrapper is still in
  # the document then, so a height of anything but zero is something painted under
  # the field on every page.
  SEARCH_CLOSED_PANEL_PROBE_JS = <<~JS
    (function() {
      var panel = document.querySelector(".navbar-search-panel");
      if (!panel) return null;
      var style = window.getComputedStyle(panel);
      return panel.getBoundingClientRect().height
        + parseFloat(style.borderTopWidth) + parseFloat(style.borderBottomWidth);
    })()
  JS

  # Where the browser painted the three boxes that must not lie on top of each
  # other: the field being typed into, the results, and the link into the full
  # answer. Read together so they share a coordinate space.
  SEARCH_OVERLAP_PROBE_JS = <<~JS
    (function() {
      var box = function(selector) {
        var element = document.querySelector(selector);
        if (!element) return null;
        var rect = element.getBoundingClientRect();
        return { top: rect.top, bottom: rect.bottom };
      };
      return [
        box(".navbar-search-input"),
        box("[data-search-target='results']"),
        box("[data-search-target='allLink']")
      ];
    })()
  JS

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

  # The box the reader types in.
  #
  # Stimulus resolves each controller through a dynamic `import()` and connects it
  # afterwards, so a keystroke delivered in between is simply dropped: the box stays
  # silent and the case fails for a reason that has nothing to do with what it is
  # checking. The shared `assert_stimulus_loaded` cannot cover that — it waits for a
  # `stimulus-loading` class the pinned Stimulus never sets, so it is satisfied as
  # soon as the page is parsed. Waiting for the connection is what lets a silent box
  # mean "no answer" here rather than "asked too early".
  def search_box
    wait_for_search_controller
    find(".navbar-search-input", visible: :all)
  end

  def wait_for_search_controller
    connected = -> { page.evaluate_script(SEARCH_CONTROLLER_CONNECTED_JS) }
    deadline = Time.now + 10
    sleep 0.05 until connected.call || Time.now > deadline
    assert connected.call, "the search controller never connected, so the box cannot answer"
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

  # The "all results" link is the reader's way into the full answer, and it was
  # absolutely positioned against the form and then moved with `bottom`, which
  # resolves to the bottom of the *field*: the panel is out of flow, so the form is
  # no taller than the input. As soon as results arrived, the link was laid across
  # the bottom of the field, covering the text being typed and the caret with it.
  # Only a browser can answer where two boxes actually land, so the geometry is
  # measured here rather than argued about in the stylesheet.
  test "the all-results link sits below the panel, never over the text being typed" do
    stub_engine
    sign_in_via_form(users(:user_one))
    visit universe_characters_path(universe_slug: @universe.slug)

    # A closed box has to leave nothing under the field. The panel's surface is
    # applied only while something is shown, and the box is on every page of the
    # application, so a surface that painted an empty wrapper would hang a dark
    # strip under the search field everywhere.
    closed = page.evaluate_script(SEARCH_CLOSED_PANEL_PROBE_JS)
    assert_not_nil closed, "the search panel was not on the page"
    assert_equal 0, closed,
      "the closed search panel is #{closed}px tall, so it paints something under the field"

    search_box.fill_in with: "hannah"
    assert_selector "[data-search-target='results'] [role='option']"
    assert_link "See all results"

    # All three boxes are read in one evaluation, so they share one coordinate space
    # and one rounding. Measured separately, each offset is rounded on its own and a
    # sub-pixel disagreement reads as an overlap that is not there.
    field, panel, all_link = page.evaluate_script(SEARCH_OVERLAP_PROBE_JS)
    assert field, "the search field was not on the page"
    assert panel, "the results panel was not on the page"
    assert all_link, "the all-results link was not on the page"

    # Sub-pixel layout rounding, so this is about the boxes being stacked rather than
    # about a tenth of a pixel of flex arithmetic.
    tolerance = 1

    assert_operator all_link["top"], :>=, field["bottom"] - tolerance,
      "the all-results link starts #{(field['bottom'] - all_link['top']).round(1)}px above the " \
      "bottom of the search field, so it covers the text being typed"
    assert_operator all_link["top"], :>=, panel["bottom"] - tolerance,
      "the all-results link starts #{(panel['bottom'] - all_link['top']).round(1)}px above the " \
      "bottom of the results panel, so the two overlap"
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
    # The link is the panel's footer, drawn with a hairline above it. With nothing to
    # open there must be no footer at all, or the panel ends in an empty strip under a
    # message that already says there is no answer.
    assert_no_link "See all results"

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

  # A run's legibility is a question about the colors a reader actually receives,
  # and a browser is the only thing that can answer it: a translucent fill is
  # resolved onto whatever is painted beneath it, so the color that decides the
  # ratio is not the one written in the stylesheet. This composites the mark and
  # the line it sits in the way they are really painted and returns every ratio
  # the case below needs.
  MATCH_CONTRAST_PROBE = <<~JS
    (function() {
      var parse = function(css) {
        var p = css.match(/[\\d.]+/g).map(Number);
        return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
      };
      var over = function(top, bottom) {
        var a = top.a + bottom.a * (1 - top.a);
        if (a === 0) return { r: 0, g: 0, b: 0, a: 0 };
        return {
          r: (top.r * top.a + bottom.r * bottom.a * (1 - top.a)) / a,
          g: (top.g * top.a + bottom.g * bottom.a * (1 - top.a)) / a,
          b: (top.b * top.a + bottom.b * bottom.a * (1 - top.a)) / a,
          a: a
        };
      };
      // The surface behind an element: its own fill at whatever share it is
      // opaque, over the nearest ancestor that finally is.
      var behind = function(el) {
        var stack = [];
        for (var node = el; node; node = node.parentElement) {
          var fill = parse(getComputedStyle(node).backgroundColor);
          if (fill.a === 0) continue;
          stack.push(fill);
          if (fill.a === 1) break;
        }
        var result = { r: 255, g: 255, b: 255, a: 1 };
        for (var i = stack.length - 1; i >= 0; i--) result = over(stack[i], result);
        return result;
      };
      var luminance = function(c) {
        var f = function(v) {
          v /= 255;
          return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        };
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
      };
      var ratio = function(one, other) {
        var a = luminance(one), b = luminance(other);
        return Math.round(((Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)) * 100) / 100;
      };
      var contrast = function(el) {
        var surface = behind(el);
        return ratio(over(parse(getComputedStyle(el).color), surface), surface);
      };

      var panel = "[data-search-target='results'] ";
      var mark = document.querySelector(panel + ".navbar-search-result-title mark");
      if (!mark) return null;
      var context = document.querySelector(panel + ".navbar-search-result-context");

      return {
        marked: contrast(mark),
        // The context line is the panel's dimmest text, and it shares the mark's
        // surface, so the two are a fair thing to set side by side.
        dimmest: contrast(context || mark.parentElement),
        separation: ratio(behind(mark), behind(mark.parentElement))
      };
    })()
  JS

  test "the matched run is more readable than the line it sits in, not less" do
    stub_engine
    sign_in_via_form(users(:user_one))
    visit universe_characters_path(universe_slug: @universe.slug)

    search_box.fill_in with: "hannah"
    assert_selector "[data-search-target='results'] .navbar-search-result-title mark", text: "Hannah"

    contrast = page.evaluate_script(MATCH_CONTRAST_PROBE)

    # The run is the one thing in the panel the reader is looking for, so it has
    # to clear the bar on its own fill...
    assert_operator contrast["marked"], :>=, 4.5,
      "the marked run is only #{contrast['marked']}:1 against its own background"
    # ...it has to be the *most* legible thing on the panel rather than the
    # least, which is what a translucent amber did: 35% amber over the panel's
    # near-black resolves to a brown around #6a571b, and white on that measures
    # 6.9:1, a step *below* the panel's own dimmest line at 7.9:1, so the word
    # the reader was hunting for was the hardest thing in the list to read. In a
    # stylesheet that still looks like a highlight.
    assert_operator contrast["marked"], :>=, contrast["dimmest"],
      "the marked run is #{contrast['marked']}:1 while the panel's dimmest line is " \
      "#{contrast['dimmest']}:1, so the highlight is the least legible thing on screen"
    # And the fill has to be visibly different from the panel, or there is no
    # box to see and the reader is left guessing where the match began. The
    # brown was 2.4:1 against the panel, which is very nearly invisible.
    assert_operator contrast["separation"], :>=, 3.0,
      "the mark's fill is only #{contrast['separation']}:1 against the panel behind it"
  end

  test "a guest can use the box on a public universe" do
    stub_engine
    visit universe_characters_path(universe_slug: @universe.slug)

    search_box.fill_in with: "hannah"

    assert_selector "[data-search-target='results'] [role='option']", text: "Hannah"
  end
end
