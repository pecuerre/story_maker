require "test_helper"

class SceneTropeTest < ActiveSupport::TestCase
  test "a scene detection carries context independently of its Story annotation" do
    scene_assignment = SceneTrope.create!(scene: scenes(:scene_two), trope_slug: "red-herring", context_note: "A different use.")
    story_assignment = story_tropes(:story_one_red_herring)

    assert_equal "red-herring", scene_assignment.trope_slug
    assert_equal "A different use.", scene_assignment.context_note
    assert_equal "The clue is introduced fairly and resolved later.", story_assignment.context_note
  end

  test "an unknown trope slug is refused" do
    assignment = SceneTrope.new(scene: scenes(:scene_one), trope_slug: "unknown")

    assert_not assignment.valid?
    assert_includes assignment.errors[:trope_slug], "is not included in the list"
  end

  test "Scene soft deletion retains annotations for restoration" do
    assignment = scene_tropes(:scene_one_red_herring)

    scenes(:scene_one).soft_delete

    assert SceneTrope.exists?(assignment.id)
    scenes(:scene_one).restore
    assert_equal "red-herring", scenes(:scene_one).scene_tropes.first.trope_slug
  end

  test "removing an assignment frees the same reference for that scene again" do
    assignment = scene_tropes(:scene_one_red_herring)

    assignment.destroy!

    replacement = SceneTrope.create!(scene: scenes(:scene_one), trope_slug: "red-herring")
    assert_predicate replacement, :persisted?
  end

  test "a Scene change remembered before the Tropes tab still applies its nested payload" do
    scene = scenes(:scene_two)

    scene.update!(scene_tropes_attributes: {
      "0" => { trope_slug: "chekhovs-gun", selected: "1", context_note: "The detail pays off later." }
    })

    assignment = scene.scene_tropes.find_by!(trope_slug: "chekhovs-gun")
    assert_equal "The detail pays off later.", assignment.context_note
  end

  test "a draft row can name and link an assignment through the Tropes tab" do
    assignment = scene_tropes(:scene_one_red_herring)

    assert_equal "Red Herring", assignment.display_label
    assert_equal Rails.application.routes.url_helpers.universe_story_scene_scene_tropes_path(
      universe_slug: scenes(:scene_one).universe.slug,
      story_id: scenes(:scene_one).story_id,
      scene_id: scenes(:scene_one).id
    ), assignment.search_url
  end
end
