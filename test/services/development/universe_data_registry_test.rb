require "test_helper"

class UniverseDataRegistryTest < ActiveSupport::TestCase
  test "registers the dependency order and supported universes" do
    model_names = Development::UniverseDataRegistry.model_names

    assert_equal "User", model_names.first
    # Scene is loaded after Event because it may reference a shared universe
    # Event, and a symbolic reference may not point at a later model file. Its
    # own components follow it for the same reason: they reference a Scene.
    assert_equal "SceneCharacter", model_names.last
    assert_operator model_names.index("Event"), :<, model_names.index("Scene")
    assert_operator model_names.index("Section"), :<, model_names.index("Scene")
    assert_operator model_names.index("SceneTag"), :<, model_names.index("Scene")
    assert_operator model_names.index("Scene"), :<, model_names.index("SceneElement")
    assert_operator model_names.index("SceneElement"), :<, model_names.index("SceneCharacter")
    assert_not_includes model_names, "Session"
    assert_equal %w[dark lotr], Development::UniverseDataRegistry::UNIVERSES.keys
    assert Development::UniverseDataRegistry.registered_universe?("dark")
    assert_not Development::UniverseDataRegistry.registered_universe?("star_wars")
  end

  test "a scene-owned model is scoped to a scene and positioned flat" do
    element = Development::UniverseDataRegistry.definition_for_model("SceneElement")
    link = Development::UniverseDataRegistry.definition_for_model("SceneCharacter")

    assert_equal :scene, element.scope
    assert_predicate element, :positioned?
    assert_not element.hierarchical_position?
    assert_equal :scene, link.scope
    assert_not link.positioned?
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
