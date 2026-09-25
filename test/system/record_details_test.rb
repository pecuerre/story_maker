require "application_system_test_case"

class RecordDetailsTest < ApplicationSystemTestCase
  test "a taxonomy row leads to the tag's page and lists the records carrying it" do
    universe = universes(:universe_one)
    tag = character_tags(:character_tag_one)
    character = characters(:character_one)

    sign_in_via_form(users(:user_one))
    visit universe_character_tags_path(universe_slug: universe.slug)
    assert_stimulus_loaded

    within "li[data-node-id='#{tag.id}'] > .taxonomy-row" do
      click_link "Details"
    end

    assert_selector "h1", text: tag.name
    assert_current_path universe_character_tag_path(universe_slug: universe.slug, id: tag)
    within ".detail-section" do
      assert_selector "a[href='#{universe_character_path(universe_slug: universe.slug, id: character)}']",
        text: character.name
    end
  end

  test "a section Details link opens the page for the scenes in that section" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    section = sections(:section_one)
    scene = scenes(:scene_one)

    sign_in_via_form(users(:user_one))
    visit universe_story_sections_path(universe_slug: universe.slug, story_id: story)

    within "li[data-node-id='#{section.id}'] > .taxonomy-row" do
      click_link "Details (1 scene)"
    end

    assert_selector "h1", text: section.name
    assert_current_path universe_story_section_path(universe_slug: universe.slug, story_id: story, id: section)
    within ".detail-section", text: "Scenes in this section" do
      assert_selector "a[href='#{universe_story_scene_path(universe_slug: universe.slug, story_id: story, id: scene)}']",
        text: scene.name
    end
  end

  test "the sidebar groups the universe, the story, and the tools" do
    universe = universes(:universe_one)
    story = stories(:story_one)

    sign_in_via_form(users(:user_one))
    visit universe_story_path(universe_slug: universe.slug, id: story)

    within "aside.workspace-sidebar" do
      # The two context blocks carry the name and one important fact each.
      assert_selector ".sidebar-context--universe .sidebar-universe-name", text: universe.name
      assert_selector ".sidebar-context--story .sidebar-story-name", text: story.name
      assert_selector ".sidebar-context--story", text: "sections"
      assert_selector ".sidebar-context--story", text: "scenes"

      # Universe Bible comes first, then the story context, then the story
      # workspace, and Configuration last.
      # The titles are uppercase in the rendered text, like every section header.
      assert_equal [ "UNIVERSE BIBLE", "STORY WORKSPACE", "CONFIGURATION" ],
        all(".workspace-navigation .sidebar-section-title").map { |title| title.text.strip }
      assert_selector ".workspace-navigation .sidebar-context--story", count: 1
    end
  end

  test "placeholder navigation is greyed out and never looks like a live link" do
    universe = universes(:universe_one)

    sign_in_via_form(users(:user_one))
    visit universe_path(universe)

    within "aside.right-sidebar" do
      assert_selector "a.sidebar-placeholder-link[aria-disabled='true']", minimum: 1
    end
  end
end
