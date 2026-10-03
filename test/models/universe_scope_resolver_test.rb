require "test_helper"

# Authorization and the shared view helpers must resolve a record's Universe the
# same way, or a writer sees missing controls while a record-level check denies
# an allowed mutation. Both paths are covered here.
class UniverseScopeResolverTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
  end

  test "resolves a direct universe owner" do
    assert_equal @universe, UniverseScopeResolver.universe_for(characters(:character_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(events(:event_one))
  end

  test "resolves a story-scoped record through its story" do
    assert_equal @universe, UniverseScopeResolver.universe_for(sections(:section_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(section_tags(:section_tag_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(scene_tags(:scene_tag_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(scenes(:scene_one))
  end

  test "resolves a scene-owned record through its scene" do
    scene = scenes(:scene_one)
    component = Struct.new(:scene).new(scene)

    assert_equal @universe, UniverseScopeResolver.universe_for(component)
  end

  test "resolves the real scene-owned models through their scene" do
    assert_equal @universe, UniverseScopeResolver.universe_for(scene_elements(:narration_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(scene_elements(:dialogue_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(scene_characters(:scene_character_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(scene_characters(:scene_character_two))
    assert_equal @universe, UniverseScopeResolver.universe_for(scene_items(:scene_item_one))
    assert_equal @universe, UniverseScopeResolver.universe_for(scene_locations(:scene_location_one))
    # Unsaved records own nothing yet, so there is no universe to resolve.
    assert_nil UniverseScopeResolver.universe_for(SceneElement.new(name: "Unsaved"))
    assert_nil UniverseScopeResolver.universe_for(SceneCharacter.new)
    assert_nil UniverseScopeResolver.universe_for(SceneItem.new)
    assert_nil UniverseScopeResolver.universe_for(SceneLocation.new)
  end

  test "a deeper component resolves through its own universe delegation" do
    # A speaker link belongs to a Scene Element rather than directly to a Scene.
    # It therefore delegates through its owner instead of adding an entry here,
    # and the resolver picks that delegation up on its first step.
    element = Struct.new(:universe).new(@universe)
    speaker = Struct.new(:universe, :scene_element).new(element.universe, element)

    assert_equal @universe, UniverseScopeResolver.universe_for(speaker)
  end

  test "resolves a section-owned record through its section" do
    section_owned = Struct.new(:section).new(sections(:section_two))

    assert_equal @universe, UniverseScopeResolver.universe_for(section_owned)
  end

  test "returns nil when nothing in the chain owns a universe" do
    assert_nil UniverseScopeResolver.universe_for(nil)
    assert_nil UniverseScopeResolver.universe_for(Story.new(name: "Unsaved"))
    assert_nil UniverseScopeResolver.universe_for(Struct.new(:story).new(nil))
  end

  test "the ability and the view helper agree for a scene and a scene-owned record" do
    ability = Ability.new(users(:user_one))
    scene = scenes(:scene_one)
    scene_owned = Struct.new(:scene).new(scene)

    assert_equal UniverseScopeResolver.universe_for(scene),
      UniverseScopeResolver.universe_for(scene_owned)
    assert_equal UniverseScopeResolver.universe_for(scene_owned),
      ability.send(:universe_for, scene_owned)
    assert ability.can?(:write, scene)
  end

  # The same walk, asked of a class rather than of a record, because three callers
  # need it before there is a record to walk from: the remembering path choosing
  # the column a create stores, the applier choosing the collection to order, and a
  # draft's own page telling that plumbing from something it can print.

  test "names the owner association a model reaches its universe through" do
    assert_equal :story, UniverseScopeResolver.owner_association_for(Section)
    assert_equal :story, UniverseScopeResolver.owner_association_for(Scene)
    assert_equal :scene, UniverseScopeResolver.owner_association_for(SceneElement)
    assert_equal :scene, UniverseScopeResolver.owner_association_for(SceneCharacter)
    # A record with a `universe_id` of its own has no owner association to walk.
    assert_nil UniverseScopeResolver.owner_association_for(Character)
  end

  test "the answer agrees with the walk, for every model it is asked about" do
    [ Section, Scene, SceneElement, SceneCharacter, Character ].each do |model|
      record = model.first
      next if record.nil?

      owner = UniverseScopeResolver.owner_association_for(model)
      walked = owner ? record.public_send(owner)&.universe : record.universe

      assert_equal UniverseScopeResolver.universe_for(record), walked,
        "#{model.name}: the column the derivation reads and the walk the resolver performs must reach the " \
        "same universe, or a remembered change would be placed in a scope the record is not in"
    end
  end
end
