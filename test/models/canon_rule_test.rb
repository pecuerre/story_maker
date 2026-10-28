require "test_helper"

class CanonRuleTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
  end

  test "requires a statement" do
    rule = CanonRule.new(universe: @universe)

    assert_not rule.valid?
    assert_includes rule.errors[:statement], "can't be blank"
  end

  test "a rule without a story is universe-wide and a rule naming one belongs to it" do
    wide = CanonRule.create!(universe: @universe, statement: "Magic always costs a memory.")
    owned = CanonRule.create!(universe: @universe, story: @story, statement: "The river is closed at night.")

    assert_predicate wide, :universe_wide?
    assert_not_predicate owned, :universe_wide?
    assert_equal "Magic always costs a memory.", wide.display_string
    assert_includes @universe.canon_rules, wide
    assert_includes @universe.canon_rules, owned
    assert_includes @story.canon_rules, owned
  end

  test "a story from another universe is refused" do
    rule = CanonRule.new(universe: @universe, story: stories(:story_two), statement: "Never here.")

    assert_not rule.valid?
    assert_includes rule.errors[:story], "must belong to the same universe"
  end

  test "a story id that names nothing is a field error rather than a foreign key failure" do
    rule = CanonRule.new(universe: @universe, statement: "Never anywhere.", story_id: 999_999)

    assert_not rule.valid?
    assert_includes rule.errors[:story], "does not exist"
  end

  test "source is optional and is the search body" do
    rule = CanonRule.create!(universe: @universe, statement: "Roads take days.")
    document = rule.search_document

    assert_nil rule.source
    assert_equal "canon_rule", document[:kind]
    assert_equal "Roads take days.", document[:title]
    assert_nil document[:body]
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
