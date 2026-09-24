require "application_system_test_case"

class WorkspaceNavigationTest < ApplicationSystemTestCase
  test "a selected story can navigate to characters and create an untagged character" do
    user = users(:user_one)
    universe = universes(:universe_one)
    story = stories(:story_one)

    sign_in_via_form(user)
    visit universe_path(universe)
    click_link "Browse stories"
    within("article", text: story.name) do
      click_link "Open story"
    end

    assert_selector "h1", text: story.name
    assert_selector ".sidebar-story-name", text: story.name

    within "nav[aria-label='Universe and story navigation']" do
      click_link "Characters"
    end
    assert_selector "h1", text: "Characters"
    assert_current_path universe_characters_path(universe_slug: universe.slug)
    within "nav[aria-label='Character workspace']" do
      assert_selector "a", count: 4
      assert_selector "a.active", text: "Characters"
      assert_selector "a", text: "Character tags"
      assert_selector "a", text: "Relations"
      assert_selector "a", text: "Relation tags"
    end

    click_button "Add character"
    assert_selector ".modal.show"
    within ".modal.show" do
      fill_in "Name", with: "Browser Character"
      fill_in "Description", with: "Created from a system test."
      click_button "Save character"
    end

    within ".entity-list" do
      assert_selector ".entity-title", text: "Browser Character"
      assert_selector ".entity-description", text: "Created from a system test."
    end

    within "nav[aria-label='Universe and story navigation']" do
      click_link "Timeline"
    end
    assert_selector "h1", text: "Timeline"
    assert_current_path universe_timeline_path(universe_slug: universe.slug)
    assert_selector ".timeline-node", minimum: 2
  end

  test "a private read member can browse without mutation controls" do
    universe = Universe.create!(owner: users(:user_one), name: "Private browser universe", slug: "private-browser", private: true)
    story = Story.create!(universe: universe, name: "Private browser story")
    UniverseMembership.create!(universe: universe, user: users(:user_two), access_level: :read)

    sign_in_via_form(users(:user_two))
    visit universe_characters_path(universe_slug: universe.slug)

    assert_selector ".access-notice", text: "read-only"
    assert_no_selector "button", text: "Add character"
    assert_no_selector ".modal"
    assert_no_selector ".row-actions"

    visit universe_story_sections_path(universe_slug: universe.slug, story_id: story)
    assert_selector "h1", text: "Sections"
    assert_no_selector ".taxonomy-separator-add"
    assert_no_selector "[data-action*='dragstart']"
  end
end
