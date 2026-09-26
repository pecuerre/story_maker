require "test_helper"

class SceneElementTest < ActiveSupport::TestCase
  setup do
    @scene = scenes(:scene_one)
    @narration = scene_elements(:narration_one)
    @dialogue = scene_elements(:dialogue_one)
    @characters = [ characters(:character_one), characters(:character_two) ]
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

  test "a scene owns and cascades its elements" do
    assert_includes @scene.scene_elements, @narration
    assert_not_includes scenes(:scene_alt).scene_elements, @narration

    assert_difference("SceneElement.count", -1) do
      scenes(:scene_alt).destroy!
    end
  end

  test "deleting a scene removes its elements and their speaker links" do
    scene = @scene
    speaker_ids = @dialogue.character_ids

    assert_difference("SceneElement.count", -4) do
      scene.destroy!
    end

    assert_equal speaker_ids.length, Character.where(id: speaker_ids).count
    assert_equal 0, ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM scene_element_speakers WHERE scene_element_id NOT IN (SELECT id FROM scene_elements)"
    ).to_i
  end

  test "deleting a character removes its speaker links but never a scene or element" do
    character = @characters.first
    element_ids = @scene.scene_elements.ids

    assert_no_difference([ "Scene.count", "SceneElement.count" ]) do
      character.destroy!
    end

    assert_equal element_ids.sort, @scene.scene_elements.reorder(:position, :id).ids.sort
    assert_equal [ @characters.last ], @dialogue.reload.characters
  end

  test "a dialogue must name at least one speaker" do
    element = SceneElement.new(scene: @scene, name: "Nobody speaks", kind: SceneElement::DIALOGUE)

    assert_not element.valid?
    assert_includes element.errors[:character_ids], "is required for a dialogue element"
  end

  test "narration cannot keep speakers" do
    @dialogue.kind = SceneElement::NARRATION

    assert_not @dialogue.valid?
    assert_includes @dialogue.errors[:kind], "cannot be Narration while speakers are still assigned"

    # The explicit confirmation clears them in the same atomic update.
    @dialogue.character_ids = []

    assert_predicate @dialogue, :valid?
    assert @dialogue.save
    assert_empty @dialogue.reload.characters
  end

  test "narration with an empty submitted speaker list is accepted" do
    element = SceneElement.new(scene: @scene, name: "No speakers", kind: SceneElement::NARRATION,
      character_ids: [ "" ])

    assert_predicate element, :valid?
  end

  test "a speaker from another universe is refused instead of raising" do
    outsider = universes(:universe_two).characters.create!(name: "Outsider")

    element = SceneElement.new(scene: @scene, name: "Wrong speaker", kind: SceneElement::DIALOGUE,
      character_ids: [ outsider.id ])

    assert_not element.valid?
    assert_includes element.errors[:character_ids], "must belong to the scene's universe"
    assert_empty element.characters
  end

  test "an unknown or repeated speaker id is an ordinary validation error" do
    unknown = SceneElement.new(scene: @scene, name: "Ghost", kind: SceneElement::DIALOGUE,
      character_ids: [ 0 ])
    assert_not unknown.valid?
    assert_includes unknown.errors[:character_ids], "must exist"

    repeated = SceneElement.new(scene: @scene, name: "Twice", kind: SceneElement::DIALOGUE,
      character_ids: [ @characters.first.id, @characters.first.id ])
    assert_not repeated.valid?
    assert_includes repeated.errors[:character_ids], "must be unique"
  end

  test "a direct association assignment is checked for the shared universe" do
    outsider = universes(:universe_two).characters.create!(name: "Outsider")
    element = SceneElement.new(scene: @scene, name: "Sneaky", kind: SceneElement::DIALOGUE)
    element.characters = [ outsider ]

    assert_not element.valid?
    assert_includes element.errors[:character_ids], "must belong to the scene's universe"
  end

  test "a dialogue may name many speakers but records no turn order" do
    assert_equal @characters.sort_by(&:id), @dialogue.characters.order(:id).to_a
    assert_equal 2, @dialogue.characters.size
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
end
