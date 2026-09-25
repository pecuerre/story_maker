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
      # The count sits with the name on the left and spells out what it counts;
      # the link itself says only "Details" and is visible without hovering.
      assert_selector ".record-count", text: "(1 character)", visible: :visible
      assert_selector "a.details-link", text: "Details", visible: :visible
      assert_selector ".taxonomy-actions .dropdown-toggle", visible: :visible
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
      assert_selector ".record-count", text: "(1 scene)", visible: :visible
      click_link "Details"
    end

    assert_selector "h1", text: section.name
    assert_current_path universe_story_section_path(universe_slug: universe.slug, story_id: story, id: section)
    within ".detail-section", text: "Scenes in this section" do
      assert_selector "a[href='#{universe_story_scene_path(universe_slug: universe.slug, story_id: story, id: scene)}']",
        text: scene.name
    end
  end

  test "the left sidebar groups the universe and the story, and Configuration is on the right" do
    universe = universes(:universe_one)
    story = stories(:story_one)

    sign_in_via_form(users(:user_one))
    visit universe_story_path(universe_slug: universe.slug, id: story)

    within "aside.workspace-sidebar" do
      # Each context block states its scope and names the current record in it.
      # The scope labels are uppercase in the rendered text, like every eyebrow.
      assert_selector ".sidebar-context--universe .sidebar-eyebrow", text: "CURRENT UNIVERSE"
      assert_selector ".sidebar-context--universe .sidebar-universe-name", text: universe.name
      assert_selector ".sidebar-context--story .sidebar-eyebrow", text: "CURRENT STORY"
      assert_selector ".sidebar-context--story .sidebar-story-name", text: story.name

      # Universe Bible comes first, then the story context, then the story
      # workspace. Configuration and Tags are not in this column.
      # The titles are uppercase in the rendered text, like every section header.
      assert_equal [ "UNIVERSE BIBLE", "STORY WORKSPACE" ],
        all(".workspace-navigation .sidebar-section-title").map { |title| title.text.strip }
      assert_selector ".workspace-navigation .sidebar-context--story", count: 1
      assert_no_selector ".workspace-navigation .sidebar-section--tools"
      assert_no_selector "a", text: "Tags"
    end

    # The right utility sidebar owns the tools scope: a green context block
    # followed by Configuration with the shared taxonomy entry and Members.
    within "aside.right-sidebar" do
      assert_selector ".sidebar-context--tools .sidebar-eyebrow", text: "UNIVERSE TOOLS"
      assert_equal [ "CONFIGURATION", "COLLABORATION", "ANALYTICS", "AI" ],
        all(".sidebar-section-title").map { |title| title.text.strip }
      within "section[aria-labelledby='configuration-title']" do
        assert_selector "a.sidebar-link[href='#{universe_tags_path(universe_slug: universe.slug)}']", text: "Tags"
        assert_selector "a.sidebar-link[href='#{universe_memberships_path(universe_slug: universe.slug)}']",
          text: "Members"
      end
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
