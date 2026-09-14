require "test_helper"

class RelationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @character_one = characters(:character_one)
    @character_two = characters(:character_two)
    @relation_type = RelationType.create!(universe: @universe, name: "Child of")
    sign_in_as(users(:user_one))
  end

  test "should get index with relation options" do
    get universe_relations_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Relations"
    assert_includes response.body, @character_one.name
    assert_includes response.body, @relation_type.name
  end

  test "should create relation and redirect" do
    assert_difference("Relation.count") do
      post universe_relations_url(universe_slug: @universe.slug), params: {
        relation: {
          character1_id: @character_one.id,
          character2_id: @character_two.id,
          relation_type_ids: [ @relation_type.id ],
          description: "They are family"
        }
      }
    end

    assert_redirected_to universe_relations_url(universe_slug: @universe.slug)
    assert_equal "They are family", Relation.order(:id).last.description
  end

  test "should update relation and redirect" do
    relation = Relation.create!(universe: @universe, character1: @character_one, character2: @character_two, relation_types: [ @relation_type ])

    patch universe_relation_url(universe_slug: @universe.slug, id: relation), params: {
      relation: { description: "Updated description" }
    }

    assert_redirected_to universe_relations_url(universe_slug: @universe.slug)
    assert_equal "Updated description", relation.reload.description
  end
end
