require "test_helper"

class SceneElementTest < ActiveSupport::TestCase
  setup do
    @scene = scenes(:scene_one)
    @narration = scene_elements(:narration_one)
    @dialogue = scene_elements(:dialogue_one)
  end

  test "requires a scene, a title, and a known kind" do
    element = SceneElement.new(name: "", kind: nil)

    assert_not element.valid?
    assert_includes element.errors[:scene], "must exist"
    assert_includes element.errors[:name], "can't be blank"
    assert_includes element.errors[:kind], "can't be blank"

    element.name = "Typed"
    element.kind = "aside"
    assert_not element.valid?
    assert_includes element.errors[:kind], "is not included in the list"
  end

  test "narration is the default kind" do
    assert_equal SceneElement::NARRATION, SceneElement.new.kind
  end

  test "a narration element needs nothing but a title" do
    assert SceneElement.create!(scene: @scene, name: "Just a title")
  end

  test "a content-free element is valid and stays content-free" do
    assert_predicate scene_elements(:narration_two), :valid?
    assert_predicate scene_elements(:narration_two).body, :blank?
  end

  test "a dialogue with no turns yet is valid" do
    element = SceneElement.new(scene: @scene, name: "A conversation to come", kind: SceneElement::DIALOGUE)

    assert_predicate element, :valid?
    assert element.save
  end

  test "resolves its universe through its scene" do
    assert_equal universes(:universe_one), @narration.universe
    assert_nil SceneElement.new(name: "Orphan").universe
  end

  test "the element sequence is flat and contiguous inside its own scene" do
    assert_not SceneElement.column_names.include?("parent_id")
    assert_equal [ 0, 1, 2, 3 ], @scene.scene_elements.reorder(:position, :id).pluck(:position)
    # The other story's element sequence is its own and starts again at zero.
    assert_equal [ 0 ], scenes(:scene_alt).scene_elements.reorder(:position, :id).pluck(:position)
  end

  test "a scene owns and cascades its elements and their turns" do
    assert_includes @scene.scene_elements, @narration
    assert_not_includes scenes(:scene_alt).scene_elements, @narration
    turn_ids = @dialogue.scene_dialogue_turns.ids

    assert_difference("SceneElement.count", -4) do
      assert_difference("SceneDialogueTurn.count", -turn_ids.length) do
        scenes(:scene_one).destroy!
      end
    end

    assert_empty SceneDialogueTurn.where(id: turn_ids)
  end

  test "deleting a character removes the turns it spoke but never a scene or element" do
    character = characters(:character_three)
    element_ids = @scene.scene_elements.ids

    assert_no_difference([ "Scene.count", "SceneElement.count" ]) do
      assert_difference("SceneDialogueTurn.count", -1) do
        character.destroy!
      end
    end

    assert_equal element_ids.sort, @scene.scene_elements.reorder(:position, :id).ids.sort
    assert_equal [ "One, two, three. Again, and slower this time." ], @dialogue.reload.scene_dialogue_turns.map(&:body)
  end

  test "a Dialogue with turns cannot become Narration" do
    @dialogue.kind = SceneElement::NARRATION

    assert_not @dialogue.valid?
    assert_includes @dialogue.errors[:kind], "cannot be Narration while dialogue turns remain"
  end

  test "a soft-deleted turn still prevents changing its Element to Narration" do
    scene_dialogue_turns(:turn_one).soft_delete
    @dialogue.kind = SceneElement::NARRATION

    assert_not @dialogue.valid?
    assert_includes @dialogue.errors[:kind], "cannot be Narration while dialogue turns remain"
  end

  test "the kind column is not named type" do
    assert_includes SceneElement.column_names, "kind"
    assert_not SceneElement.column_names.include?("type")
  end

  test "the database refuses a kind the model does not know" do
    assert_raises(ActiveRecord::StatementInvalid) do
      @narration.update_column(:kind, "aside")
    end
  end

  test "content stores its whitespace-delimited word count on every save" do
    element = SceneElement.create!(
      scene: @scene, name: "Counted", kind: SceneElement::NARRATION, body: "One two three."
    )

    assert_equal 3, element.word_count

    element.update!(body: "One two")
    assert_equal 2, element.word_count

    element.update!(body: "")
    assert_equal 0, element.word_count
  end
end
