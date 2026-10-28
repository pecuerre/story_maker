require "test_helper"

# The Story-wide Scene matrix reads one row per Scene and the facts already
# stored on it. The counts are grouped reads, and presence is the same union the
# Characters tab, the Scenes list, and the Appearance grid report.
class SceneMatrixTest < ActiveSupport::TestCase
  setup do
    @story = stories(:story_one)
  end

  def matrix
    SceneMatrix.new(@story)
  end

  test "rows keep the story's narrative order" do
    assert_equal [ scenes(:scene_one), scenes(:scene_two), scenes(:scene_three) ], matrix.scenes
  end

  test "element, word, and participant counts are read per scene" do
    rows = matrix

    # scene_one holds four Elements, their Content plus two Dialogue turn lines,
    # and the union of two stored links and three speaking Characters.
    assert_equal 4, rows.element_count_for(scenes(:scene_one))
    assert_equal 38, rows.word_count_for(scenes(:scene_one))
    assert_equal 3, rows.participant_count_for(scenes(:scene_one))

    # A Scene with nothing recorded answers a real zero rather than a missing key.
    assert_equal 0, rows.element_count_for(scenes(:scene_two))
    assert_equal 0, rows.word_count_for(scenes(:scene_two))
    assert_equal 0, rows.participant_count_for(scenes(:scene_two))
  end

  test "a scene's own prose is its elements and its dialogue turns, never a sibling's" do
    scenes(:scene_three).scene_elements.create!(
      scene: scenes(:scene_three), name: "Loose beat", kind: SceneElement::NARRATION,
      body: "Four five"
    )

    rows = matrix

    assert_equal 38, rows.word_count_for(scenes(:scene_one))
    assert_equal 2, rows.word_count_for(scenes(:scene_three))
  end

  test "a soft-deleted scene and its prose leave the matrix" do
    scenes(:scene_two).soft_delete

    rows = matrix

    assert_equal [ scenes(:scene_one), scenes(:scene_three) ], rows.scenes
    assert_equal 2, rows.scenes.size
  end

  test "a soft-deleted element stops counting toward its scene" do
    scene_elements(:narration_one).soft_delete

    rows = matrix

    assert_equal 3, rows.element_count_for(scenes(:scene_one))
    assert_equal 22, rows.word_count_for(scenes(:scene_one))
  end

  test "another story's scenes never reach this story's matrix" do
    assert_not_includes matrix.scenes, scenes(:scene_alt)
  end
end
