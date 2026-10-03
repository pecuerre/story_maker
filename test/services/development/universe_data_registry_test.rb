require "test_helper"

class UniverseDataRegistryTest < ActiveSupport::TestCase
  test "registers the dependency order and supported universes" do
    model_names = Development::UniverseDataRegistry.model_names

    assert_equal "User", model_names.first
    # Scene is loaded after Event because it may reference a shared universe
    # Event, and a symbolic reference may not point at a later model file. Its
    # own components follow it for the same reason: they reference a Scene.
    # Discussion follows every one of them, because a thread's `record` reference
    # may name any of them.
    assert_equal "DiscussionMessage", model_names.last
    assert_operator model_names.index("Discussion"), :<, model_names.index("DiscussionMessage")
    Ability::CONTENT_CLASS_NAMES.each do |class_name|
      assert_operator model_names.index(class_name), :<, model_names.index("Discussion"),
        "#{class_name} must load before a thread may be about it"
    end
    assert_operator model_names.index("Event"), :<, model_names.index("Scene")
    assert_operator model_names.index("Section"), :<, model_names.index("Scene")
    assert_operator model_names.index("SceneTag"), :<, model_names.index("Scene")
    assert_operator model_names.index("Scene"), :<, model_names.index("SceneElement")
    assert_operator model_names.index("SceneElement"), :<, model_names.index("SceneCharacter")
    # Item and Location are universe-scoped, so their presence links may only
    # reference them once they have already been loaded.
    assert_operator model_names.index("Item"), :<, model_names.index("SceneItem")
    assert_operator model_names.index("Location"), :<, model_names.index("SceneLocation")
    assert_operator model_names.index("SceneItem"), :<, model_names.index("SceneLocation")
    assert_not_includes model_names, "Session"
    assert_equal %w[dark lotr], Development::UniverseDataRegistry::UNIVERSES.keys
    assert Development::UniverseDataRegistry.registered_universe?("dark")
    assert_not Development::UniverseDataRegistry.registered_universe?("star_wars")
  end

  test "a scene-owned model is scoped to a scene and positioned flat" do
    element = Development::UniverseDataRegistry.definition_for_model("SceneElement")
    link = Development::UniverseDataRegistry.definition_for_model("SceneCharacter")
    item = Development::UniverseDataRegistry.definition_for_model("SceneItem")
    place = Development::UniverseDataRegistry.definition_for_model("SceneLocation")

    assert_equal :scene, element.scope
    assert_predicate element, :positioned?
    assert_not element.hierarchical_position?
    assert_equal :scene, link.scope
    assert_not link.positioned?
    # The two remaining world-presence links are the same shape: Scene-owned,
    # unpositioned, and reaching the Universe through their Scene.
    assert_equal :scene, item.scope
    assert_not item.positioned?
    assert_equal :scene, place.scope
    assert_not place.positioned?
  end

  test "distinguishes hierarchical and flat position groups" do
    hierarchical = Development::UniverseDataRegistry::ModelDefinition.new(
      model_name: "Section",
      file_name: "sections",
      scope: :story,
      positioned: true
    )
    flat = Development::UniverseDataRegistry::ModelDefinition.new(
      model_name: "Scene",
      file_name: "scenes",
      scope: :story,
      positioned: true,
      position_mode: :flat
    )

    assert hierarchical.hierarchical_position?
    assert_not flat.hierarchical_position?
  end

  test "normalizes universe names before looking them up" do
    assert_equal "dark", Development::UniverseDataRegistry.directory_name_for(" DARK ")
  end

  test "matches registered and checked-in universe directories" do
    assert_nothing_raised do
      Development::UniverseDataRegistry.validate_directories!(Rails.root)
    end
  end
end
