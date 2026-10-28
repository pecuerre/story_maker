require "test_helper"

# The Story-wide appearance grid. Recorded presence and prose mentions are two
# independent answers per cell, and a row exists when either layer names the
# Character somewhere in this Story.
class AppearanceGridTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @story = @universe.stories.create!(name: "Grid story")
    @mira = @universe.characters.create!(name: "Mira")
    @nico = @universe.characters.create!(name: "Nico")
    @pia = @universe.characters.create!(name: "Pia")
    @unaffiliated = @universe.characters.create!(name: "Unaffiliated")

    @first = @story.scenes.create!(name: "First", position: 0)
    @second = @story.scenes.create!(name: "Second", position: 1)
    @third = @story.scenes.create!(name: "Third", position: 2)

    @first.scene_characters.create!(character: @mira)
    @first.scene_elements.create!(name: "Mira block", kind: "narration", body: "Mira waits.")
    @second.scene_elements.create!(name: "Nico block", kind: "narration", body: "Nico watches.")
    @third.scene_characters.create!(character: @pia)
  end

  def grid
    AppearanceGrid.new(@story)
  end

  test "columns keep the story's narrative order" do
    assert_equal [ @first, @second, @third ], grid.scenes
  end

  test "a row exists for a recorded presence or a prose mention, but not for an unused character" do
    assert_equal [ @mira, @nico, @pia ], grid.characters
    assert_not_includes grid.characters, @unaffiliated
  end

  test "the two layers become one of four cell states without being merged" do
    rows = grid

    assert_equal :both, rows.state_for(@mira, @first)
    assert_equal :none, rows.state_for(@nico, @first)
    assert_equal :mention, rows.state_for(@nico, @second)
    assert_equal :present, rows.state_for(@pia, @third)
    assert_equal :none, rows.state_for(@mira, @third)
  end

  test "a mention never becomes a recorded appearance" do
    rows = grid

    assert rows.mentioned?(@nico, @second)
    assert_not rows.appears?(@nico, @second)
    assert_empty @second.scene_characters.where(character: @nico)
  end

  test "an event linked to a scene does not add a character row" do
    @second.scene_events.create!(event: events(:event_one))

    assert_not_includes grid.characters, @unaffiliated
  end

  test "a story with no scenes has no columns and no rows" do
    empty = @universe.stories.create!(name: "Empty grid")
    rows = AppearanceGrid.new(empty)

    assert_empty rows.scenes
    assert_empty rows.characters
    assert_not rows.scenes?
    assert_not rows.characters?
  end

  test "a story with scenes but no presence or mentions has no rows" do
    story = @universe.stories.create!(name: "Bare grid")
    story.scenes.create!(name: "Empty scene", position: 0)
    rows = AppearanceGrid.new(story)

    assert rows.scenes?
    assert_not rows.characters?
  end

  test "a soft-deleted scene contributes neither a column nor a cell" do
    @second.soft_delete
    rows = grid

    assert_equal [ @first, @third ], rows.scenes
    assert_not_includes rows.characters, @nico
  end
end
