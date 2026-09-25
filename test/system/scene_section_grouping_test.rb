require "application_system_test_case"

class SceneSectionGroupingTest < ApplicationSystemTestCase
  test "a writer groups scenes from the sections workspace without changing the narrative order" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    scene = scenes(:scene_three)
    assert_nil scene.section

    sign_in_via_form(users(:user_one))
    visit universe_story_sections_path(universe_slug: universe.slug, story_id: story)

    assert_selector "h2", text: "Ungrouped scenes"
    assert_selector ".scene-grouping", text: "Ungrouped"
    assert_selector ".scene-grouping", text: "Scene three"
    assert_selector ".scene-grouping .list-group-item .badge", text: "1 ungrouped scene"

    # The form lives in the Ungrouped surface, so it only offers an ungrouped
    # scene: a grouped scene is regrouped from its own section's page.
    assert_selector "select[name=scene_id] option", count: 1
    select "3. Scene three", from: "Ungrouped scene"
    select "Section one", from: "Move to"
    click_button "Move scene"

    assert_selector ".alert-success", text: "is now grouped under Section one"
    assert_selector ".alert-success", text: "narrative position did not change"

    # A grouped scene leaves this list: it is listed on its own section's page.
    assert_no_selector ".scene-grouping .list-group-item", text: "Scene three"
    assert_selector ".scene-grouping", text: "nothing waiting to"
    find("a.details-link[aria-label^='Details for Section one']").click
    assert_selector "h1", text: "Section one"
    assert_selector ".detail-section", text: "Scene three"

    visit universe_story_scenes_path(universe_slug: universe.slug, story_id: story)
    assert_equal [ "Scene one", "Scene two", "Scene three" ], scene_titles
    assert_selector ".entity-row", text: "Scene three"
    assert_no_selector ".entity-row", text: "Ungrouped"

    # A grouped scene comes back to Ungrouped from the scene editor, which is
    # where its Section selector lives.
    visit edit_universe_story_scene_path(universe_slug: universe.slug, story_id: story, id: scene)
    select "Ungrouped", from: "Section"
    click_button "Update Scene"

    assert_selector ".alert-success", text: "Scene was successfully updated."
    visit universe_story_sections_path(universe_slug: universe.slug, story_id: story)
    assert_selector ".scene-grouping .list-group-item", text: "Scene three"
    assert_selector ".scene-grouping .list-group-item .badge", text: "1 ungrouped scene"
    visit universe_story_scenes_path(universe_slug: universe.slug, story_id: story)
    assert_selector ".entity-row", text: "Ungrouped"
  end

  test "a writer sets the event link and the in-world time from scene details" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    scene = scenes(:scene_three)
    assert_nil scene.event

    sign_in_via_form(users(:user_one))
    visit edit_universe_story_scene_path(universe_slug: universe.slug, story_id: story, id: scene)

    assert_selector "nav.content-tabs[aria-label='Scene workspace'] a.active", text: "Scene Details"
    select "Section one", from: "Section"
    select "The end - 2026-09-11 10:00", from: "Event"
    # A datetime-local input is typed in the browser's own locale, which is not
    # the test environment's to control, so the value is set the way a real edit
    # delivers it. The round trip through the editor and back to Details is what
    # this test covers; the request tests cover rejected input.
    assert_field "In-world time", type: "datetime-local"
    find("input[name='scene[datetime]']").execute_script(<<~JS)
      const input = document.querySelector("input[name='scene[datetime]']");
      input.value = "2019-11-05T21:00";
      input.dispatchEvent(new Event("input", { bubbles: true }));
      input.dispatchEvent(new Event("change", { bubbles: true }));
    JS
    click_button "Update Scene"

    assert_selector "h1", text: scene.name
    assert_text "Section one"
    assert_text "The end - 2026-09-11 10:00"
    assert_text "2019-11-05 21:00"
    # Narrative position and in-world time stay separate on the details page.
    assert_text "3 of 3 in the order Story One is told"
    assert_text "Narrative order is not in-world chronology"

    visit universe_story_scenes_path(universe_slug: universe.slug, story_id: story)
    assert_equal [ "Scene one", "Scene two", "Scene three" ], scene_titles
  end

  test "grouping works at a narrow width and with the keyboard alone" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    long_section = story.sections.create!(name: "A very long section name that must not break the outline")
    long_scene = story.scenes.create!(
      name: "A deliberately very long scene title that should wrap instead of widening the row",
      description: "A deliberately very long short description. " * 12,
      position: 3
    )

    sign_in_via_form(users(:user_one))
    page.driver.browser.manage.window.resize_to(420, 900)

    visit universe_story_scenes_path(universe_slug: universe.slug, story_id: story)
    assert_selector ".entity-row", text: long_scene.name[0, 40]
    assert_selector ".entity-row .badge", text: "Ungrouped"

    visit universe_story_sections_path(universe_slug: universe.slug, story_id: story)
    assert_selector ".scene-grouping", text: long_section.name

    # The source selector offers only the two ungrouped scenes of this story, in
    # narrative order, and a long title stays inside its own option instead of
    # widening the page.
    assert_selector "select[name=scene_id] option", count: 2
    assert_selector "select[name=scene_id] option:first-child", text: "3. Scene three"
    assert_selector "select[name=scene_id] option", text: /A deliberately very long scene title/

    # Keyboard only. Home/End move through a select without a pointer, and the
    # submit must be reachable by tabbing, not only by clicking.
    find("#scene_grouping_scene_id").send_keys(:home)
    find("#scene_grouping_section_id").send_keys(:end)
    find("#scene_grouping_section_id").native.send_keys(:tab)
    assert_selector "input[type=submit][value='Move scene']:focus"

    find("input[type=submit][value='Move scene']").send_keys(:return)

    assert_selector ".alert-success", text: "is now grouped under A very long section name"
    # The first ungrouped scene of the story is the one that moved.
    assert_equal long_section, scenes(:scene_three).reload.section
  end

  test "a read-only member sees grouping and details without mutation controls" do
    owner = users(:user_one)
    reader = users(:user_two)
    private_universe = Universe.create!(owner: owner, name: "Private grouping", slug: "private-grouping", private: true)
    story = Story.create!(universe: private_universe, name: "Private story")
    section = story.sections.create!(name: "Private section")
    scene = story.scenes.create!(name: "Private scene", section: section)
    ungrouped = story.scenes.create!(name: "Ungrouped private scene")
    UniverseMembership.create!(universe: private_universe, user: reader, access_level: :read)

    sign_in_via_form(reader)
    visit universe_story_sections_path(universe_slug: private_universe.slug, story_id: story)

    assert_selector "h2", text: "Ungrouped scenes"
    assert_selector ".scene-grouping", text: "Ungrouped private scene"
    assert_no_selector ".scene-grouping", text: "Private scene"
    assert_no_selector "form.scene-grouping-form"
    assert_no_selector "select[name=scene_id]"

    visit universe_story_section_path(universe_slug: private_universe.slug, story_id: story, id: section)

    assert_selector "h1", text: "Private section"
    assert_selector ".detail-section", text: "Private scene"

    visit universe_story_scene_path(universe_slug: private_universe.slug, story_id: story, id: ungrouped)

    assert_selector "h1", text: "Ungrouped private scene"
    assert_text "Ungrouped."
    assert_no_link "Edit scene"
  end

  private
    def scene_titles
      page.evaluate_script(
        "Array.from(document.querySelectorAll('.entity-list .entity-title')).map(node => node.textContent.trim())"
      )
    rescue Selenium::WebDriver::Error::JavascriptError, Selenium::WebDriver::Error::NoSuchWindowError
      nil
    end
end
