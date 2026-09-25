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
    assert_equal @universe, UniverseScopeResolver.universe_for(scenes(:scene_one))
  end

  test "resolves a scene-owned record through its scene" do
    scene = scenes(:scene_one)
    component = Struct.new(:scene).new(scene)

    assert_equal @universe, UniverseScopeResolver.universe_for(component)
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
end
