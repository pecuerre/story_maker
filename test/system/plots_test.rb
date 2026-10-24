require "application_system_test_case"

class PlotsTest < ApplicationSystemTestCase
  test "a writer creates a Plot and assigns it to a Scene" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    scene = scenes(:scene_three)

    sign_in_via_form(users(:user_one))
    visit universe_story_plots_path(universe_slug: universe.slug, story_id: story)

    click_button "Add plot"
    within ".modal.show" do
      fill_in "Name", with: "Browser through-line"
      fill_in "Description", with: "Connects scenes across sections."
      click_button "Save plot"
    end
    assert_selector ".entity-row", text: "Browser through-line"

    visit edit_universe_story_scene_path(universe_slug: universe.slug, story_id: story, id: scene)
    select "Browser through-line", from: "Plots"
    click_button "Update Scene"

    assert_selector "h1", text: scene.name
    assert_link "Browser through-line", href: universe_story_plot_path(
      universe_slug: universe.slug, story_id: story,
      id: story.plots.find_by!(name: "Browser through-line")
    )
  end
end
