require "test_helper"

# The Story-wide Scene planning board groups the Story's Scenes by the Section
# each one already stores. Columns are the Section tree in order plus the
# ungrouped group, and the cards inside a column keep narrative order.
class SceneBoardTest < ActiveSupport::TestCase
  setup do
    @story = stories(:story_one)
  end

  def board
    SceneBoard.new(@story)
  end

  test "columns are every section in tree order plus ungrouped last" do
    columns = board.columns

    assert_equal [ "Section one", "Section one / Section two", "Ungrouped" ], columns.map(&:label)
    assert columns.last.ungrouped?
    assert_nil columns.last.section
    assert_equal sections(:section_one), columns.first.section
  end

  test "each column holds its own scenes in narrative order" do
    later = @story.scenes.create!(name: "Later beat", position: 3, section: sections(:section_one))

    columns = SceneBoard.new(@story).columns

    assert_equal [ scenes(:scene_one), later ], columns.first.scenes
    assert_equal [ scenes(:scene_two) ], columns.second.scenes
    assert_equal [ scenes(:scene_three) ], columns.last.scenes
  end

  test "a section with no scenes keeps its column" do
    @story.sections.create!(name: "Empty section", position: 2)

    empty = board.columns.find { |column| column.label == "Empty section" }

    assert_not_nil empty
    assert_empty empty.scenes
  end

  test "the boundary positions and grouping options come from the whole story" do
    rows = board

    assert_equal 0, rows.first_position
    assert_equal 2, rows.last_position
    assert_equal [
      [ "Ungrouped", "" ],
      [ "Section one", sections(:section_one).id ],
      [ "— Section two", sections(:section_two).id ]
    ], rows.grouping_options
  end

  test "another story's sections and scenes never reach the board" do
    rows = board

    assert_not_includes rows.columns.map(&:label), "Section alt"
    assert_not_includes rows.scenes, scenes(:scene_alt)
  end

  test "a story with no scenes has no cards but still has its columns" do
    empty = @story.universe.stories.create!(name: "Empty story")

    rows = SceneBoard.new(empty)

    assert_not rows.scenes?
    assert_empty rows.scenes
    assert_equal [ "Ungrouped" ], rows.columns.map(&:label)
  end
end
