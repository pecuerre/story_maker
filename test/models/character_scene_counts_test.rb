require "test_helper"

# The Story overview's scenes-per-character counts. The count is the presence
# union `SceneParticipants` reports, scoped to one Story's live Scenes.
class CharacterSceneCountsTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @story = @universe.stories.create!(name: "Cast story")
    @mira = @universe.characters.create!(name: "Mira")
    @nico = @universe.characters.create!(name: "Nico")
    @pia = @universe.characters.create!(name: "Pia")
    @unused = @universe.characters.create!(name: "Unused")

    @first = @story.scenes.create!(name: "First", position: 0)
    @second = @story.scenes.create!(name: "Second", position: 1)
    @third = @story.scenes.create!(name: "Third", position: 2)

    @first.scene_characters.create!(character: @mira)
    @second.scene_characters.create!(character: @mira)
    @second.scene_elements.create!(name: "Nico on stage", kind: "dialogue")
      .scene_dialogue_turns.create!(speaker: @nico, body: "I am here.")
    @third.scene_characters.create!(character: @pia)
  end

  def counts
    CharacterSceneCounts.for(@story)
  end

  test "counts the scenes in which each character appears" do
    assert_equal({ @mira => 2, @nico => 1, @pia => 1 },
      counts.entries.to_h { |entry| [ entry.character, entry.scene_count ] })
  end

  test "orders by appearances and then by name" do
    assert_equal [ @mira, @nico, @pia ], counts.entries.map(&:character)
  end

  test "a character who only speaks is counted without a presence link" do
    entry = counts.entries.find { |item| item.character == @nico }

    assert_equal 1, entry.scene_count
    assert_empty @second.scene_characters.where(character: @nico)
  end

  test "a character who both participates and speaks in one scene is counted once" do
    element = @first.scene_elements.create!(name: "Mira speaks", kind: "dialogue")
    element.scene_dialogue_turns.create!(speaker: @mira, body: "Also me.")

    assert_equal 2, counts.entries.find { |item| item.character == @mira }.scene_count
  end

  test "the denominator is the story's whole live scene count" do
    assert_equal 3, counts.scene_count
    assert_in_delta 66.7, counts.share_for(counts.entries.first), 0.1
  end

  test "a character who appears nowhere in the story is left out" do
    assert_not_includes counts.entries.map(&:character), @unused
  end

  test "a story with no scenes has a zero denominator and no rows" do
    empty = @universe.stories.create!(name: "Empty cast")
    counts = CharacterSceneCounts.for(empty)

    assert_equal 0, counts.scene_count
    assert_empty counts.entries
    assert_not counts.any?
    assert_not counts.scenes?
  end

  test "a scene where nobody appears contributes to the denominator but no row" do
    @first.scene_characters.destroy_all
    @first.scene_elements.destroy_all
    counts = CharacterSceneCounts.for(@story)

    assert_equal 3, counts.scene_count
    assert_equal [ @mira, @nico, @pia ], counts.entries.map(&:character)
  end

  test "another story's scenes do not count" do
    other = @universe.stories.create!(name: "Another cast")
    other.scenes.create!(name: "Away", position: 0).scene_characters.create!(character: @unused)

    assert_not_includes counts.entries.map(&:character), @unused
  end

  test "a soft-deleted scene contributes nothing" do
    @second.soft_delete
    counts = CharacterSceneCounts.for(@story)

    assert_equal 2, counts.scene_count
    assert_equal [ @mira, @pia ], counts.entries.map(&:character)
    assert_equal 1, counts.entries.first.scene_count
  end

  test "an event link does not add a character" do
    @second.scene_events.create!(event: events(:event_one))

    assert_not_includes counts.entries.map(&:character), @unused
  end

  test "a prose mention does not add an appearance" do
    mentioned = @universe.characters.create!(name: "Whisper")
    @third.scene_elements.create!(name: "A name in prose", kind: "narration", body: "Whisper watches.")

    assert_not_includes counts.entries.map(&:character), mentioned
  end

  test "a soft-deleted character leaves the chart" do
    @pia.soft_delete

    assert_not_includes counts.entries.map(&:character), @pia
  end
end
