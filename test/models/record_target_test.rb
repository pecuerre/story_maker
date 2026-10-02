require "test_helper"

# A polymorphic reference is two strings that arrived from outside: a type that
# must not be constantized and an id that is only meaningful inside the universe
# the request already authorized. These cover both halves, and the registry rule
# that keeps one answer to "which classes can be named".
class RecordTargetTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @character = characters(:character_one)
  end

  test "resolves a registered content class to its record" do
    record = RecordTarget.find(record_type: "Character", record_id: @character.id)

    assert_equal @character, record
    assert_equal Character, RecordTarget.model_for("Character")
  end

  test "resolves a record through every kind of content owner" do
    [
      [ "Story", stories(:story_one) ],
      [ "Section", sections(:section_one) ],
      [ "Scene", scenes(:scene_one) ],
      [ "SceneElement", scene_elements(:narration_one) ],
      [ "SceneCharacter", scene_characters(:scene_character_one) ],
      [ "CharacterTag", character_tags(:character_tag_one) ]
    ].each do |type, record|
      assert_equal record, RecordTarget.find(record_type: type, record_id: record.id), type
    end
  end

  test "a type outside the registry is not loaded, whatever it names" do
    # The registry is the gate. A class that CanCan has no rule for must not be
    # reachable through a reference at all, so none of these resolve — including
    # the ones that are real, loadable constants and the ones that are not.
    [ "User", "Session", "UniverseMembership", "ActiveRecord::Base", "Kernel",
      "::Character", " character", "Character ", "characters", "" ].each do |type|
      assert_nil RecordTarget.model_for(type), type.inspect
      assert_nil RecordTarget.find(record_type: type, record_id: @character.id), type.inspect
    end

    assert_nil RecordTarget.model_for(nil)
    assert_nil RecordTarget.find(record_type: nil, record_id: @character.id)
  end

  test "a registered type with an id that names nothing resolves to nil" do
    assert_nil RecordTarget.find(record_type: "Character", record_id: nil)
    assert_nil RecordTarget.find(record_type: "Character", record_id: 0)
    assert_nil RecordTarget.find(record_type: "Character", record_id: @character.id + 100_000)
  end

  test "a soft-deleted record is not a resolvable reference" do
    @character.soft_delete

    assert_nil RecordTarget.find(record_type: "Character", record_id: @character.id)
    assert_raises ActiveRecord::RecordNotFound do
      RecordTarget.find!(record_type: "Character", record_id: @character.id)
    end
  end

  test "find! refuses an unknown type, an unknown id, and a blank reference alike" do
    [
      { record_type: "Nope", record_id: @character.id },
      { record_type: "Character", record_id: nil },
      { record_type: nil, record_id: nil }
    ].each do |reference|
      error = assert_raises ActiveRecord::RecordNotFound do
        RecordTarget.find!(**reference, within: @universe)
      end

      assert_equal RecordTarget::NOT_FOUND, error.message
    end
  end

  test "find! refuses a record that belongs to another universe" do
    other_universe = Universe.create!(owner: users(:user_one), name: "Elsewhere", slug: "elsewhere")
    foreign = other_universe.characters.create!(name: "Stranger")

    assert_equal foreign, RecordTarget.find(record_type: "Character", record_id: foreign.id)

    error = assert_raises ActiveRecord::RecordNotFound do
      RecordTarget.find!(record_type: "Character", record_id: foreign.id, within: @universe)
    end

    assert_equal RecordTarget::NOT_FOUND, error.message
  end

  test "find! accepts a record inside the universe it is scoped to" do
    assert_equal @character,
      RecordTarget.find!(record_type: "Character", record_id: @character.id, within: @universe)
  end

  test "a record that resolves to no universe is not owned by any universe" do
    # Unsaved records own nothing, so the walk finds no universe. Failing the same
    # check as a foreign record is deliberate: a reference that cannot place its
    # record is not one this application can honour.
    unsaved = Character.new(name: "Unsaved")

    assert_nil UniverseScopeResolver.universe_for(unsaved)
    assert_not RecordTarget.owned_by?(unsaved, @universe)
    assert_not RecordTarget.owned_by?(unsaved, Universe.new(id: @universe.id + 1))
  end

  test "owned_by? agrees with the resolver Ability authorizes through" do
    ability = Ability.new(users(:user_one))

    assert RecordTarget.owned_by?(@character, @universe)
    assert RecordTarget.owned_by?(scenes(:scene_one), @universe)
    assert RecordTarget.owned_by?(scene_elements(:narration_one), @universe)
    assert_not RecordTarget.owned_by?(@character, Universe.new(id: @universe.id + 1))
    assert_not RecordTarget.owned_by?(Character.new(name: "Unsaved"), @universe)

    # The point of delegating: the answer must be the one Ability will act on, so a
    # generic reference path cannot authorize one record and render another.
    assert_equal ability.send(:universe_for, @character), UniverseScopeResolver.universe_for(@character)
  end

  test "resolvable? answers the model-validation shape without raising" do
    other_universe = Universe.create!(owner: users(:user_one), name: "Elsewhere", slug: "elsewhere")
    foreign = other_universe.characters.create!(name: "Stranger")

    assert RecordTarget.resolvable?(record_type: "Character", record_id: @character.id, within: @universe)
    assert_not RecordTarget.resolvable?(record_type: "Character", record_id: foreign.id, within: @universe)
    assert_not RecordTarget.resolvable?(record_type: "Character", record_id: nil, within: @universe)
    assert_not RecordTarget.resolvable?(record_type: "Nope", record_id: @character.id, within: @universe)

    # Without a universe the question is only "does this name a record".
    assert RecordTarget.resolvable?(record_type: "Character", record_id: foreign.id)
    assert_not RecordTarget.resolvable?(record_type: "Character", record_id: 0)
  end
end
