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
end
