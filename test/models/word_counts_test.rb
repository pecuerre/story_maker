require "test_helper"

# The prose rollups a Section row and the Story page state: Element Content and
# Dialogue turn lines, summed per Scene, then up a Section's ancestors.
class WordCountsTest < ActiveSupport::TestCase
  setup do
    @story = stories(:story_one)
  end

  test "every fixture's stored count matches its body" do
    SceneElement.find_each do |element|
      assert_equal WordCountable.words_in(element.body), element.word_count,
        "#{element.name.inspect} fixture word_count is stale"
    end

    SceneDialogueTurn.find_each do |turn|
      assert_equal WordCountable.words_in(turn.body), turn.word_count,
        "Dialogue turn #{turn.id} fixture word_count is stale"
    end
  end

  test "a story total sums element content and dialogue turn lines" do
    # scene_one holds 16 + 11 words of Element Content and 3 + 8 words of turns.
    assert_equal 38, WordCounts.for_story(@story).total
  end

  test "a section total includes its descendant sections" do
    scenes(:scene_two).scene_elements.create!(
      scene: scenes(:scene_two), name: "The next beat", kind: SceneElement::NARRATION,
      body: "One two three"
    )

    counts = WordCounts.for_story(@story)

    assert_equal 3, counts.for_section(sections(:section_two))
    assert_equal 41, counts.for_section(sections(:section_one))
  end

  test "an ungrouped scene counts toward the story but toward no section" do
    scenes(:scene_three).scene_elements.create!(
      scene: scenes(:scene_three), name: "Loose beat", kind: SceneElement::NARRATION,
      body: "Four five"
    )

    counts = WordCounts.for_story(@story)

    assert_equal 40, counts.total
    assert_equal 38, counts.for_section(sections(:section_one))
    assert_equal 0, counts.for_section(sections(:section_two))
  end

  test "a scene total sums only that scene's prose" do
    counts = WordCounts.for_story(@story)

    assert_equal 38, counts.for_scene(scenes(:scene_one))
    assert_equal 0, counts.for_scene(scenes(:scene_two))
  end

  test "a section of another story has no words here" do
    assert_equal 0, WordCounts.for_story(@story).for_section(sections(:section_alt))
  end

  test "another story's prose never reaches this story's total" do
    scenes(:scene_alt).scene_elements.create!(
      scene: scenes(:scene_alt), name: "Elsewhere", kind: SceneElement::NARRATION,
      body: "Nine ten eleven"
    )

    assert_equal 38, WordCounts.for_story(@story).total
    assert_equal 3, WordCounts.for_story(stories(:story_alt)).total
    assert_equal 0, WordCounts.for_story(@story).for_scene(scenes(:scene_alt))
  end

  test "soft-deleted element content and turns leave the total" do
    scene_elements(:dialogue_one).soft_delete

    assert_equal 16, WordCounts.for_story(@story).total
  end
end
