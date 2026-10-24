require "test_helper"

# A turn is one spoken line inside a Dialogue Element: a same-Universe speaker,
# the line, an optional parenthetical, and a flat position inside its Element.
class SceneDialogueTurnTest < ActiveSupport::TestCase
  setup do
    @element = scene_elements(:dialogue_one)
    @speaker = characters(:character_one)
    @other_speaker = characters(:character_two)
    @outsider = characters(:character_other_universe)
  end

  def build_turn(attributes = {})
    SceneDialogueTurn.new(
      scene_element: @element,
      speaker: @speaker,
      body: "Count with me.",
      **attributes
    )
  end

  test "requires an element, a speaker, and a dialogue element" do
    t = build_turn
    assert t.valid?

    t.scene_element = nil
    assert_not t.valid?
    assert_includes t.errors[:scene_element], "must exist"

    t.scene_element = @element
    t.speaker = nil
    assert_not t.valid?
    assert_includes t.errors[:speaker], "must exist"
  end

  test "a narration element cannot carry a turn" do
    t = build_turn(scene_element: scene_elements(:narration_one))

    assert_not t.valid?
    assert_includes t.errors[:base], "a narration element cannot carry a turn"
  end

  test "a speaker from another universe is refused" do
    t = build_turn(speaker: @outsider)

    assert_not t.valid?
    assert_includes t.errors[:speaker], "must belong to the scene's universe"
  end

  test "an unknown speaker is an ordinary validation error" do
    t = SceneDialogueTurn.new(scene_element: @element, speaker_id: 0)

    assert_not t.valid?
    assert_includes t.errors[:speaker], "must exist"
  end

  test "resolves its universe through its element" do
    assert_equal universes(:universe_one), build_turn.universe
    assert_nil SceneDialogueTurn.new.universe
  end

  test "the turn sequence is flat and contiguous inside its own element" do
    assert_not SceneDialogueTurn.column_names.include?("parent_id")
    assert_equal [ 0, 1 ], @element.scene_dialogue_turns.reorder(:position, :id).pluck(:position)
  end

  test "soft delete and restore normalize the Element's turn sequence" do
    first, second = @element.scene_dialogue_turns.reorder(:position, :id).to_a

    first.soft_delete
    assert_equal [ [ second.id, 0 ] ], @element.scene_dialogue_turns.order(:position, :id).pluck(:id, :position)

    first.restore
    assert_equal [ [ first.id, 0 ], [ second.id, 1 ] ],
      @element.scene_dialogue_turns.order(:position, :id).pluck(:id, :position)
  end

  test "soft-deleting an element soft-deletes its turns and keeps the speaker" do
    turn_ids = @element.scene_dialogue_turns.pluck(:id)
    speaker_ids = SceneDialogueTurn.where(id: turn_ids).pluck(:speaker_id)

    assert_difference -> { SceneDialogueTurn.only_deleted.count }, 2 do
      @element.soft_delete
    end

    assert @element.reload.deleted?
    turn_ids.each do |id|
      assert SceneDialogueTurn.only_deleted.find(id).deleted?
    end
    assert_equal speaker_ids.uniq.sort, Character.where(id: speaker_ids.uniq).pluck(:id).sort,
      "a shared character survives the turn it spoke in"
  end
end
