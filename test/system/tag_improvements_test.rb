require "application_system_test_case"

class TagImprovementsTest < ApplicationSystemTestCase
  test "a show_in_menu tag is a workspace tab that opens the same page as the taxonomy Details link" do
    universe = universes(:universe_one)
    tag = character_tags(:character_tag_one)

    sign_in_via_form(users(:user_one))
    visit universe_characters_path(universe_slug: universe.slug)
    assert_stimulus_loaded

    within "nav.content-tabs" do
      # The tab states where it was opened from, so the tag page can keep this
      # navigation without trusting a Referer header it does not control.
      assert_selector "a[href='#{universe_character_tag_path(universe_slug: universe.slug, id: tag, from: "workspace")}']"
      click_link tag.name
    end

    assert_current_path universe_character_tag_path(universe_slug: universe.slug, id: tag, from: "workspace")
    assert_selector "h1", text: tag.name
    assert_selector ".detail-section", text: "Characters with this tag"

    # The taxonomy tree's Details link reaches the same page without the origin,
    # so the two are the same destination reached two documented ways: the
    # workspace tab keeps the tab strip, the canonical link does not.
    visit universe_character_tags_path(universe_slug: universe.slug)
    within "li[data-node-id='#{tag.id}'] > .taxonomy-row" do
      find("a.details-link").click
    end

    assert_current_path universe_character_tag_path(universe_slug: universe.slug, id: tag)
  end

  test "a menu tag's tab strip reads above its identity card" do
    universe = universes(:universe_one)
    tag = character_tags(:character_tag_one)

    sign_in_via_form(users(:user_one))
    visit universe_characters_path(universe_slug: universe.slug)
    assert_stimulus_loaded

    within "nav.content-tabs" do
      click_link tag.name
    end

    assert_equal [ "header", "tabs", "card" ], page_blocks
  end

  test "a tag's details page shows every tag next to each listed record" do
    universe = universes(:universe_one)
    tag = character_tags(:character_tag_one)
    character = characters(:character_one)

    sign_in_via_form(users(:user_one))
    visit universe_character_tag_path(universe_slug: universe.slug, id: tag)
    assert_stimulus_loaded

    within ".detail-section" do
      assert_selector "a", text: character.name
      assert_selector ".taxonomy-tag", text: tag.name
    end
  end

  test "the taxonomy editor carries a Taggable checkbox and a content tag offers Show in menu" do
    universe = universes(:universe_one)
    tag = character_tags(:character_tag_one)

    sign_in_via_form(users(:user_one))
    visit universe_character_tags_path(universe_slug: universe.slug)
    assert_stimulus_loaded

    # The row is scoped to the node's own row: a tag with children nests their
    # `li` inside this one, and each of those rows has a collapsed menu of its
    # own, so the bare node scope holds more than one toggle.
    within "li[data-node-id='#{tag.id}'] > .taxonomy-row" do
      find("button[aria-expanded='false']").click
      click_button "Edit"
    end

    within ".modal.show" do
      assert_field "Taggable"
      assert_field "Show in menu"
      uncheck "Taggable"
      click_button "Save changes"
    end

    assert_selector "li[data-node-id='#{tag.id}'] .taxonomy-name-trigger"
    assert_not tag.reload.taggable
  end

  test "a read-only member sees the read-only empty copy on an empty taxonomy" do
    owner = users(:user_one)
    reader = users(:user_two)
    universe = Universe.create!(owner: owner, name: "Empty tag copy", slug: "empty-tag-copy", private: true)
    UniverseMembership.create!(universe: universe, user: reader, access_level: :read)

    sign_in_via_form(reader)
    visit universe_character_tags_path(universe_slug: universe.slug)
    assert_stimulus_loaded

    assert_selector ".empty-state", text: "No character tags are defined yet."
    assert_no_selector ".empty-state", text: "Add one to group characters"
  end

  private

    # The tag page's own blocks in the order the browser stacks them. The tab
    # strip is page navigation, so it reads as one with the header above the
    # identity card rather than as a strip pushed below it.
    def page_blocks
      page.all("main .page-shell > header.page-header, main .page-shell > nav.content-tabs, main .page-shell > .surface-card").map do |block|
        classes = block["class"].to_s
        next "header" if classes.include?("page-header")
        next "tabs" if classes.include?("content-tabs")
        next "card" if classes.include?("surface-card")
      end
    end
end
