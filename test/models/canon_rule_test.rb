require "test_helper"

class CanonRuleTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
  end

  test "requires a name and a statement" do
    rule = CanonRule.new(universe: @universe)

    assert_not rule.valid?
    assert_includes rule.errors[:name], "can't be blank"
    assert_includes rule.errors[:statement], "can't be blank"
  end

  test "a rule without a story is universe-wide and a rule naming one belongs to it" do
    wide = CanonRule.create!(universe: @universe, name: "Memory's price", statement: "Magic always costs a memory.")
    owned = CanonRule.create!(universe: @universe, story: @story, name: "Night crossing",
      statement: "The river is closed at night.")

    assert_predicate wide, :universe_wide?
    assert_not_predicate owned, :universe_wide?
    assert_equal "Memory's price", wide.display_string
    assert_includes @universe.canon_rules, wide
    assert_includes @universe.canon_rules, owned
    assert_includes @story.canon_rules, owned
  end

  test "a story from another universe is refused" do
    rule = CanonRule.new(universe: @universe, story: stories(:story_two), name: "Nowhere", statement: "Never here.")

    assert_not rule.valid?
    assert_includes rule.errors[:story], "must belong to the same universe"
  end

  test "a story id that names nothing is a field error rather than a foreign key failure" do
    rule = CanonRule.new(universe: @universe, name: "Nowhere", statement: "Never anywhere.", story_id: 999_999)

    assert_not rule.valid?
    assert_includes rule.errors[:story], "does not exist"
  end

  test "a blank slug is derived once from the name and survives a rename" do
    rule = CanonRule.create!(universe: @universe, name: "Night crossing", statement: "The river runs backwards.")

    assert_equal "night-crossing", rule.slug

    rule.update!(name: "The night crossing")

    assert_equal "night-crossing", rule.slug
  end

  test "an explicit slug is normalized and kept as written otherwise" do
    rule = CanonRule.create!(universe: @universe, name: "Trigger", slug: "L7", statement: "The mechanism starts.")

    assert_equal "l7", rule.slug
  end

  test "a live slug is unique inside its universe and reusable in another" do
    CanonRule.create!(universe: @universe, name: "First", slug: "k99", statement: "One.")

    duplicate = CanonRule.new(universe: @universe, name: "Second", slug: "k99", statement: "Two.")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
    assert CanonRule.new(universe: universes(:universe_two), name: "Second", slug: "k99", statement: "Two.").valid?
  end

  test "a canon type is optional and restricted to the ledger's four kinds" do
    assert CanonRule.new(universe: @universe, name: "Plain", statement: "One.").valid?
    assert CanonRule.new(universe: @universe, name: "Locked", canon_type: "locked", statement: "One.").valid?

    rule = CanonRule.new(universe: @universe, name: "Unknown", canon_type: "suggestion", statement: "One.")

    assert_not rule.valid?
    assert_includes rule.errors[:canon_type], "is not included in the list"
  end

  test "the search document is named by the rule and searches its statement and source" do
    rule = CanonRule.create!(universe: @universe, name: "Roads take days",
      statement: "Every road between the gates takes three days.", source: "Chapter four.")

    document = rule.search_document

    assert_equal "canon_rule", document[:kind]
    assert_equal "Roads take days", document[:title]
    assert_equal "Every road between the gates takes three days. Chapter four.", document[:body]
    assert_equal @universe.id, document[:universe_id]
  end

  test "soft deleting hides the rule and restoring brings it back" do
    rule = canon_rules(:canon_rule_one)

    rule.soft_delete
    assert_predicate rule.reload, :deleted?
    assert_not_includes @universe.canon_rules, rule

    rule.restore
    assert_includes @universe.canon_rules, rule
  end

  test "soft deleting a story takes its own rules and leaves the universe's" do
    owned = canon_rules(:canon_rule_two)
    wide = canon_rules(:canon_rule_one)

    @story.soft_delete

    assert_predicate owned.reload, :deleted?
    assert_not_predicate wide.reload, :deleted?
  end
end
