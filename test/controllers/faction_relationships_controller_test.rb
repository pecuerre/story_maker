require "test_helper"

class FactionRelationshipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @from = factions(:faction_one)
    @to = factions(:faction_two)
    sign_in_as(users(:user_one))
  end

  test "index shows the faction workspace tab and relationship editor" do
    get universe_faction_relationships_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".page-header h1", text: "Faction relationships"
    assert_select "nav.content-tabs a[href=?][aria-current=page]",
      universe_faction_relationships_path(universe_slug: @universe.slug)
    assert_select "nav.content-tabs a[href=?]", universe_factions_path(universe_slug: @universe.slug), text: "Factions"
    assert_select "select[name='faction_relationship[from_faction_id]']"
    assert_select "select[name='faction_relationship[to_faction_id]']"
  end

  test "creates a directed relationship and redirects" do
    assert_difference("FactionRelationship.count") do
      post universe_faction_relationships_url(universe_slug: @universe.slug), params: {
        faction_relationship: {
          name: "Uneasy alliance",
          from_faction_id: @from.id,
          to_faction_id: @to.id,
          description: "They cooperate when their interests overlap."
        }
      }
    end

    assert_redirected_to universe_faction_relationships_url(universe_slug: @universe.slug)
    relationship = FactionRelationship.order(:id).last
    assert_equal @from, relationship.from_faction
    assert_equal @to, relationship.to_faction
  end

  test "the inverse direction can be stored independently" do
    forward = FactionRelationship.create!(universe: @universe, from_faction: @from, to_faction: @to)

    assert_difference("FactionRelationship.count") do
      post universe_faction_relationships_url(universe_slug: @universe.slug), params: {
        faction_relationship: { from_faction_id: @to.id, to_faction_id: @from.id }
      }
    end

    assert_redirected_to universe_faction_relationships_url(universe_slug: @universe.slug)
    reverse = FactionRelationship.order(:id).last
    assert_equal [ @to.id, @from.id ], [ reverse.from_faction_id, reverse.to_faction_id ]
    assert_not_equal forward.id, reverse.id
  end

  test "updates details and soft-deletes a relationship" do
    relationship = faction_relationships(:faction_relationship_one)

    patch universe_faction_relationship_url(universe_slug: @universe.slug, id: relationship), params: {
      faction_relationship: { description: "New terms apply." }
    }

    assert_response :see_other
    assert_equal "New terms apply.", relationship.reload.description

    delete universe_faction_relationship_url(universe_slug: @universe.slug, id: relationship)

    assert_response :see_other
    assert_predicate FactionRelationship.with_deleted.find(relationship.id), :deleted?
  end

  test "details identify the direction and link both factions" do
    relationship = faction_relationships(:faction_relationship_one)

    get universe_faction_relationship_url(universe_slug: @universe.slug, id: relationship)

    assert_response :success
    assert_select ".page-header h1", text: "Uneasy alliance"
    assert_select "a[href=?]", universe_faction_path(universe_slug: @universe.slug, id: @from), text: @from.name
    assert_select "a[href=?]", universe_faction_path(universe_slug: @universe.slug, id: @to), text: @to.name
    assert_select "a[href=?]", universe_faction_relationships_path(universe_slug: @universe.slug), text: "All faction relationships"
  end

  test "rejects a self relationship and keeps its submitted values" do
    assert_no_difference("FactionRelationship.count") do
      post universe_faction_relationships_url(universe_slug: @universe.slug), params: {
        faction_relationship: { from_faction_id: @from.id, to_faction_id: @from.id, name: "Self" }
      }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger[role=alert]", text: /must be different from the source faction/
    assert_select "button[data-action='modal-form#open'][data-modal-form-values-value*=?]", '"name":"Self"'
  end

  test "rejects an endpoint from another universe" do
    assert_no_difference("FactionRelationship.count") do
      post universe_faction_relationships_url(universe_slug: @universe.slug), params: {
        faction_relationship: { from_faction_id: @from.id, to_faction_id: factions(:faction_other_universe).id }
      }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger[role=alert]", text: /must belong to the relationship's universe/
  end

  test "a guest can read relationships but has no mutation controls" do
    sign_out

    get universe_faction_relationships_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select "[data-modal-form-target='modal']", count: 0
  end

  test "private-universe relationship access follows read and write membership levels" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Relationship access",
      slug: "relationship-access", private: true)
    from = private_universe.factions.create!(name: "Private source")
    to = private_universe.factions.create!(name: "Private target")
    private_universe.faction_relationships.create!(from_faction: from, to_faction: to)

    sign_out
    sign_in_as(users(:user_two))
    get universe_faction_relationships_url(universe_slug: private_universe.slug)
    assert_response :not_found

    membership = UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)
    get universe_faction_relationships_url(universe_slug: private_universe.slug)
    assert_response :success
    assert_select "button[data-action='modal-form#open']", count: 0

    assert_no_difference("FactionRelationship.count") do
      post universe_faction_relationships_url(universe_slug: private_universe.slug), params: {
        faction_relationship: { from_faction_id: from.id, to_faction_id: to.id }
      }
    end
    assert_response :forbidden

    membership.update!(access_level: :write)
    assert_difference("FactionRelationship.count") do
      post universe_faction_relationships_url(universe_slug: private_universe.slug), params: {
        faction_relationship: { from_faction_id: from.id, to_faction_id: to.id }
      }
    end
    assert_redirected_to universe_faction_relationships_url(universe_slug: private_universe.slug)
  end

  test "a relationship from another universe is not found" do
    get universe_faction_relationship_url(universe_slug: @universe.slug,
      id: faction_relationships(:faction_relationship_other_universe))

    assert_response :not_found
  end
end
