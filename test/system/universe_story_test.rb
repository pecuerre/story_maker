require "application_system_test_case"

class UniverseStoryTest < ApplicationSystemTestCase
  test "a user can create a universe and story, then open story-scoped sections" do
    sign_in_via_form(users(:user_one))

    visit new_universe_path
    fill_in "Name", with: "System Test Universe"
    click_button "Create Universe"

    assert_selector "h1", text: "System Test Universe"
    assert_selector ".alert-success", text: "Universe was successfully created."
    # The universe page lists its stories directly and keeps an "All stories"
    # link to the full page.
    within ".page-actions" do
      click_link "All stories"
    end

    assert_selector "h1", text: "Stories", wait: 5
    click_link "New story"
    fill_in "Name", with: "System Test Story"
    fill_in "Description", with: "A story created by a system test."
    click_button "Create Story"

    assert_selector "h1", text: "System Test Story"
    assert_selector ".alert-success", text: "Story was successfully created."
    click_link "Open sections"

    assert_selector "h1", text: "Sections"
    assert_match %r{/u/system-test-universe/s/\d+/sections\z}, current_path
  end

  # The login -> universe -> story flow with more than one story present. The
  # story picker is the universe page, so switching stories is a second visit to
  # that same page rather than a dropdown, and the Universe Bible the two stories
  # share must not change when the story does.
  test "a reader signs in, opens a universe of several stories, and switches between two" do
    universe = universes(:universe_one)
    first = stories(:story_one)
    second = stories(:story_alt)

    sign_in_via_form(users(:user_one))

    # Sign-in lands on the universe list, and the universe is one click from it.
    assert_selector "h1", text: "Universes"
    click_link universe.name

    assert_selector "h1", text: universe.name
    assert_selector "#universe-stories-title", text: "2 stories"

    # No story is implied: with no selection the sidebar says so rather than
    # falling back to the first of the two.
    assert_selector ".sidebar-story-name", text: "None selected"

    find("#universe-stories-title ~ .list-group a[aria-label='Open #{first.name}']").click

    assert_selector "h1", text: first.name
    assert_selector ".sidebar-story-name", text: first.name

    # Back to the picker for the second story. The one just left is marked, so
    # the reader can see which of the two is current.
    click_link "Universe Maker"
    click_link universe.name
    assert_selector ".badge", text: "Current"
    assert_text first.name

    find("#universe-stories-title ~ .list-group a[aria-label='Open #{second.name}']").click

    assert_selector "h1", text: second.name
    assert_selector ".sidebar-story-name", text: second.name

    # The Universe Bible is shared: both stories reach the same universe-level
    # Characters, which is what makes them two stories in one universe rather
    # than two universes.
    within "nav[aria-label='Universe and story navigation']" do
      click_link "Characters"
    end

    assert_current_path universe_characters_path(universe_slug: universe.slug)
    assert_selector "h1", text: "Characters"
    within "aside.workspace-sidebar" do
      assert_selector ".sidebar-story-name", text: second.name
    end
  end

  # The two cards are stacked rather than side by side: the story list reads
  # first, and neither card is squeezed into half the page, so a long story
  # name or description has the whole width to itself.
  test "the universe page stacks the story list above the Universe Bible, both full width" do
    universe = universes(:universe_one)

    sign_in_via_form(users(:user_one))
    visit universe_path(universe_slug: universe.slug)

    assert_selector "#universe-stories-title"

    # Measured in the browser rather than through Capybara's node API, because
    # the fact under test is the layout the reader sees.
    stories_box, bible_box = page.evaluate_script(<<~JS)
      (() => {
        const main = document.querySelector("main");
        const stories = document.getElementById("universe-stories-title").closest(".surface-card");
        // The Universe Bible card is the one holding its four links. Its
        // eyebrow cannot be matched by text: CSS renders it uppercase, and the
        // same wording is also a left-sidebar section title.
        const links = [...main.querySelectorAll("a")].filter((a) => a.textContent.trim() === "Timeline");
        const bible = links[0].closest(".surface-card");
        const rect = (el) => {
          const r = el.getBoundingClientRect();
          return { top: r.top, bottom: r.bottom, width: r.width };
        };
        return [rect(stories), rect(bible)];
      })()
    JS

    # Stacked: the bible card starts at or below the story card's bottom edge,
    # never beside it.
    assert_operator bible_box["top"], :>=, stories_box["bottom"]

    # Full width: both cards span the same measure, and that measure is the
    # whole content column rather than half of it.
    assert_in_delta bible_box["width"], stories_box["width"], 1
    assert_operator bible_box["width"], :>, 600
  end

  test "a name whose address is taken is refused, and the address field answers it" do
    sign_in_via_form(users(:user_one))

    # "One" derives the address `one`, which the `universe_one` fixture already
    # holds. The refusal is a stated field error on the form, not a 500 page.
    visit new_universe_path
    fill_in "Name", with: "One"
    click_button "Create Universe"

    assert_selector ".alert-danger[role=alert] li", text: "Slug has already been taken"
    assert_equal "One", find("#universe_name").value

    fill_in "Address slug", with: "one-in-another-timeline"
    click_button "Create Universe"

    assert_selector "h1", text: "One"
    assert_match %r{/u/one-in-another-timeline\z}, current_path
  end
end
