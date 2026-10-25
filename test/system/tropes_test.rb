require "application_system_test_case"

class TropesTest < ApplicationSystemTestCase
  test "a writer annotates a trope at both Story and Scene levels" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    scene = scenes(:scene_three)

    sign_in_via_form(users(:user_one))

    visit edit_universe_story_path(universe_slug: universe.slug, id: story)
    within "[data-trope-slug='red-herring']" do
      check "Red Herring"
      fill_in "Context note", with: "The Story's clue has a deliberate payoff."
    end
    click_button "Update Story"

    assert_selector "h1", text: story.name
    assert_link "Red Herring", href: TropeCatalog.find("red-herring").source_url
    assert_text "The Story's clue has a deliberate payoff."

    visit universe_story_scene_scene_tropes_path(universe_slug: universe.slug, story_id: story, scene_id: scene)
    click_button "Add trope"
    within ".modal.show" do
      find(".ts-control").click
      find(".ts-control input").set("chek")
      find(".ts-dropdown .option", text: "Chekhov’s Gun").click
      fill_in "Context note", with: "This scene plants a detail that matters later."
      click_button "Save trope"
    end

    assert_selector ".entity-row", text: "Chekhov’s Gun", wait: REFRESH_WAIT
    assert_link "Chekhov’s Gun", href: TropeCatalog.find("chekhovs-gun").source_url
    assert_text "This scene plants a detail that matters later."

    visit universe_story_scene_path(universe_slug: universe.slug, story_id: story, id: scene)
    assert_link "Chekhov’s Gun", href: TropeCatalog.find("chekhovs-gun").source_url
    assert_text "This scene plants a detail that matters later."
  end
end
