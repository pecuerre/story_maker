require "test_helper"

class FactionRelationshipTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @from = factions(:faction_one)
    @to = factions(:faction_two)
  end

  test "a directed relationship stores its endpoints and a readable fallback" do
    relationship = FactionRelationship.create!(universe: @universe, from_faction: @from, to_faction: @to)

    assert_equal "Faction one → Faction two", relationship.display_string
    assert_equal "faction-one-faction-two", relationship.slug
  end

  test "the reverse direction is a separate relationship" do
    forward = FactionRelationship.create!(universe: @universe, from_faction: @from, to_faction: @to)
    reverse = FactionRelationship.create!(universe: @universe, from_faction: @to, to_faction: @from)

    assert_not_equal forward.id, reverse.id
    assert_equal "Faction two → Faction one", reverse.display_string
  end

  test "the optional name is the label and slug when present" do
    relationship = FactionRelationship.create!(universe: @universe, from_faction: @from, to_faction: @to,
      name: "Uneasy alliance")

    assert_equal "Uneasy alliance", relationship.display_string
    assert_equal "uneasy-alliance", relationship.slug
  end

  test "a faction cannot relate to itself" do
    relationship = FactionRelationship.new(universe: @universe, from_faction: @from, to_faction: @from)

    assert_not relationship.valid?
    assert_includes relationship.errors[:to_faction], I18n.t("faction_relationships.errors.must_be_different")
  end

  test "both endpoints must belong to the relationship universe" do
    relationship = FactionRelationship.new(universe: @universe, from_faction: @from,
      to_faction: factions(:faction_other_universe))

    assert_not relationship.valid?
    assert_includes relationship.errors[:to_faction], I18n.t("faction_relationships.errors.must_belong_to_universe")
  end

  test "deleting either endpoint soft-deletes relationships without removing their rows" do
    outgoing = FactionRelationship.create!(universe: @universe, from_faction: @from, to_faction: @to)
    other = @universe.factions.create!(name: "Third faction")
    incoming = FactionRelationship.create!(universe: @universe, from_faction: other, to_faction: @to)

    @from.soft_delete
    assert_predicate FactionRelationship.with_deleted.find(outgoing.id), :deleted?

    @to.soft_delete
    assert_predicate FactionRelationship.with_deleted.find(incoming.id), :deleted?
  end

  test "the relationship is searchable through its endpoints and description" do
    relationship = faction_relationships(:faction_relationship_one)

    assert_equal "faction_relationship", relationship.search_document[:kind]
    assert_equal "Uneasy alliance", relationship.search_document[:title]
    assert_equal relationship.description, relationship.search_document[:body]
    assert_equal "/u/one/faction_relationships/#{relationship.id}", relationship.search_document[:url]
  end
end
