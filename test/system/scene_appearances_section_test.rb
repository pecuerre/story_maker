require "application_system_test_case"

# The "Appears in scenes" section is read-only navigation on a record's own
# details page. What only a browser can prove is that the links actually land on
# the Scene they name, and that a reader with no story selected is offered the
# way to pick one instead of another story's scenes.
class SceneAppearancesSectionTest < ApplicationSystemTestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
  end

  test "a character lists the scenes it takes part in and the link lands on the scene" do
    sign_in_via_form(users(:user_one))
    visit universe_story_path(universe_slug: @universe.slug, id: @story)
    visit universe_character_path(universe_slug: @universe.slug, id: characters(:character_one))

    within "section.detail-section", text: "Appears in scenes of #{@story.name}" do
      assert_selector ".entity-row", count: 1
      assert_text "Scene one"
      assert_text "Linked"
      assert_text "Speaks in 1 element"
      assert_text "Role: setting"
      find("a.text-break", text: "Scene one").click
    end

    assert_selector "h1", text: "Scene one"
    assert_text "Michael teaches the waltz"
  end

  test "an item lists each scene it appears in, in the order the story is told" do
    sign_in_via_form(users(:user_one))
    visit universe_story_path(universe_slug: @universe.slug, id: @story)
    visit universe_item_path(universe_slug: @universe.slug, id: items(:item_one))

    within "section.detail-section", text: "Appears in scenes of #{@story.name}" do
      names = page.evaluate_script(
        "Array.from(document.querySelectorAll('.entity-row .entity-title')).map(node => node.textContent.trim())"
      )
      assert_equal [ "Scene one", "Scene three" ], names
      # The narrative position is visible from the record that knows nothing about
      # that order, and the in-world times say the opposite order.
      assert_text "Role: carries"
      assert_text "Role: still missing"
    end
  end

  test "an event lists every scene that depicts it, without merging them" do
    later = @story.scenes.create!(name: "The same fact retold", position: 3, event: events(:event_one))

    sign_in_via_form(users(:user_one))
    visit universe_story_path(universe_slug: @universe.slug, id: @story)
    visit universe_event_path(universe_slug: @universe.slug, id: events(:event_one))

    within "section.detail-section", text: "Appears in scenes of #{@story.name}" do
      names = page.evaluate_script(
        "Array.from(document.querySelectorAll('.entity-row .entity-title')).map(node => node.textContent.trim())"
      )
      assert_equal [ "Scene one", later.name ], names
      assert_selector ".badge", text: "Depicted", count: 2
    end
  end

  test "without a selected story the section asks for one rather than guessing" do
    sign_in_via_form(users(:user_one))
    # A brand-new universe has no remembered story, so the page must not fall back
    # to the first story of this one.
    other = Universe.create!(owner: users(:user_one), name: "Unscoped", slug: "unscoped", private: false)
    Story.create!(universe: other, name: "Only story")
    item = other.items.create!(name: "Unscoped prop")

    visit universe_item_path(universe_slug: other.slug, id: item)

    assert_selector ".empty-title", text: "Select a story to see its scenes"
    assert_no_selector ".detail-section a.details-link"
    # The sidebar offers the same destination, so the click is scoped to the
    # section that promised it.
    within "section.detail-section" do
      click_link "All stories"
    end
    assert_selector "h1", text: "Stories"
  end

  test "a guest reads the same section with nothing to click" do
    # Each case starts with a fresh browser, so simply not signing in is the guest
    # path this application is designed around.
    visit universe_story_path(universe_slug: @universe.slug, id: @story)
    visit universe_item_path(universe_slug: @universe.slug, id: items(:item_one))

    within "section.detail-section", text: "Appears in scenes of #{@story.name}" do
      assert_selector ".entity-row", count: 2
      assert_selector ".details-link", count: 2
    end
    assert_no_selector "main form"
    assert_no_selector ".row-actions"
  end
end
