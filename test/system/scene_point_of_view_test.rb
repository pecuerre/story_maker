require "application_system_test_case"

class ScenePointOfViewTest < ApplicationSystemTestCase
  test "a writer chooses a point-of-view character and sees it on scene details" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    scene = scenes(:scene_one)

    sign_in_via_form(users(:user_one))
    visit edit_universe_story_scene_path(universe_slug: universe.slug, story_id: story, id: scene)

    assert_selector "h1", text: "Edit scene"
    select "Character two", from: "Point of view"
    click_button "Update Scene"

    assert_selector "h1", text: scene.name
    assert_text "POINT OF VIEW"
    assert_text "Character two"
    assert_selector "a[href='#{universe_character_path(universe_slug: universe.slug, id: characters(:character_two))}']",
      text: "Character two"

    # Clearing it records no point of view instead of choosing nobody.
    # Visiting the edit URL directly: the create/update flash sits on the details
    # page and would intercept a click on its "Edit scene" link.
    visit edit_universe_story_scene_path(universe_slug: universe.slug, story_id: story, id: scene)
    select "None", from: "Point of view"
    click_button "Update Scene"

    assert_text "No point of view recorded yet."
    assert_no_selector "a[href='#{universe_character_path(universe_slug: universe.slug, id: characters(:character_two))}']"
  end

  test "a read-only member sees the point of view without any control" do
    owner = users(:user_one)
    reader = users(:user_two)
    private_universe = Universe.create!(owner: owner, name: "Private pov", slug: "private-pov", private: true)
    story = Story.create!(universe: private_universe, name: "Private story")
    character = private_universe.characters.create!(name: "Private character")
    scene = story.scenes.create!(name: "Private scene", pov_character: character)
    UniverseMembership.create!(universe: private_universe, user: reader, access_level: :read)

    sign_in_via_form(reader)
    visit universe_story_scene_path(universe_slug: private_universe.slug, story_id: story, id: scene)

    assert_selector "h1", text: "Private scene"
    assert_text "POINT OF VIEW"
    assert_text "Private character"
    assert_no_link "Edit scene"
  end
end
