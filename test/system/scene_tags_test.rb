require "application_system_test_case"

class SceneTagsTest < ApplicationSystemTestCase
  test "a writer manages story scene tags and assigns one from Scene Details" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    scene = scenes(:scene_one)

    sign_in_via_form(users(:user_one))
    visit universe_story_path(universe_slug: universe.slug, id: story)
    visit universe_tags_path(universe_slug: universe.slug, scope: "story", taxonomy: "scene")

    assert_selector "h1", text: "Tags"
    assert_selector ".tag-taxonomy-tabs a.active", text: "Scene tags"
    click_button "Add scene tag"
    within ".taxonomy-new" do
      find("input[name='name']").set("Browser scene tag")
      click_button "Save"
    end
    assert_selector ".taxonomy-name-trigger", text: "Browser scene tag"

    visit edit_universe_story_scene_path(universe_slug: universe.slug, story_id: story, id: scene)
    assert_field "Scene tags", type: "select"
    select "Browser scene tag", from: "Scene tags"
    click_button "Update Scene"

    assert_selector "h1", text: scene.name
    assert_selector ".taxonomy-tag", text: "Browser scene tag"
  end

  test "a read-only member sees scene tags without mutation controls" do
    owner = users(:user_one)
    reader = users(:user_two)
    universe = Universe.create!(owner: owner, name: "Private scene tag browser", slug: "private-scene-tag-browser", private: true)
    story = Story.create!(universe: universe, name: "Private story")
    tag = story.scene_tags.create!(name: "Private beat")
    scene = story.scenes.create!(name: "Private scene")
    scene.scene_tags << tag
    UniverseMembership.create!(universe: universe, user: reader, access_level: :read)

    sign_in_via_form(reader)
    visit universe_story_scene_tags_path(universe_slug: universe.slug, story_id: story)

    assert_selector "h1", text: "Scene tags"
    assert_selector ".taxonomy-node", text: "Private beat"
    assert_no_button "Add scene tag"
    assert_no_selector "[data-taxonomy-action='move-up']"
    assert_no_selector "[data-action='taxonomy-tree#add']"

    visit universe_story_scene_path(universe_slug: universe.slug, story_id: story, id: scene)
    assert_selector ".taxonomy-tag", text: "Private beat"
    assert_no_link "Edit scene"
  end
end
