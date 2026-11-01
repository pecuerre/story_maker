require "test_helper"

# The Canon list filter is a value object, so its rules are pinned here rather
# than through the page: which column a text search really reaches, that an
# unknown canon type or a foreign Story is dropped and reported, that the
# universe-wide rules lead every order, and that a sort is a read-time choice
# and nothing else. Like the other flat lists, the request and system tests can
# only show the outcome.
class CanonRuleFilterTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @stories = @universe.stories.order(:name, :id).to_a

    # Fixed timestamps, because "newest first" and "recently edited first" are
    # only meaningful when the fixtures are not all stamped within the same
    # microsecond by the fixture loader.
    canon_rules(:canon_rule_one).update!(created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 3, 1))
    canon_rules(:canon_rule_two).update!(created_at: Time.utc(2026, 2, 1), updated_at: Time.utc(2026, 2, 10))
  end

  test "an empty filter changes nothing, keeps the universe-wide rule first, and reports itself inactive" do
    filter = filter_for

    assert_not filter.active?
    assert_not filter.narrowed?
    assert_empty filter.query_params
    assert_empty filter.discarded
    assert_equal "name", filter.sort
    assert_equal [ "Magic costs a memory", "The night crossing" ], apply(filter).map(&:name),
      "the whole universe's rules lead the list"
  end

  test "free text matches the name, the statement, or the source passage, ignoring case" do
    assert_equal [ "Magic costs a memory" ], apply(filter_for(q: "memory")).map(&:name)
    assert_equal [ "Magic costs a memory" ], apply(filter_for(q: "MEMORY")).map(&:name), "a search box ignores case"
    assert_equal [ "The night crossing" ], apply(filter_for(q: "ferryman")).map(&:name),
      "the source passage is searched, not only the rule"
  end

  test "a category is not searchable text" do
    canon_rules(:canon_rule_one).update!(name: "A quiet rule", statement: "Something quiet happens.",
      category: "a category nobody writes in prose")

    assert_empty apply(filter_for(q: "a category nobody writes in prose")).map(&:name)
  end

  test "search text is matched literally, so a wildcard is not a wildcard" do
    canon_rules(:canon_rule_one).update!(name: "100% of the oath")

    assert_equal [ "100% of the oath" ], apply(filter_for(q: "100%")).map(&:name)
    assert_equal [ "100% of the oath" ], apply(filter_for(q: "%")).map(&:name),
      "a percent sign is text to search for, not a pattern matching everything"
  end

  test "the canon type filter narrows to the rules of one type" do
    assert_equal [ "Magic costs a memory" ], apply(filter_for(canon_type: "locked")).map(&:name)
    assert_equal [ "The night crossing" ], apply(filter_for(canon_type: "rule")).map(&:name)
    assert_empty apply(filter_for(canon_type: "open")).map(&:name)
  end

  test "a canon type outside the model's vocabulary is dropped and reported" do
    forged = filter_for(canon_type: "house-rule")

    assert_not forged.active?
    assert_equal 1, forged.discarded.size
    assert_match(/not a canon type/, forged.discarded.first)
    assert_equal [ "Magic costs a memory", "The night crossing" ], apply(forged).map(&:name)
  end

  test "the scope filter narrows to one Story's rules" do
    assert_equal [ "The night crossing" ], apply(filter_for(owner_story_id: stories(:story_one).id)).map(&:name)
    assert_empty apply(filter_for(owner_story_id: stories(:story_alt).id)).map(&:name)
  end

  test "the universe-wide choice selects the rules no Story owns" do
    assert_equal [ "Magic costs a memory" ], apply(filter_for(owner_story_id: CanonRuleFilter::UNIVERSE_SCOPE)).map(&:name)
  end

  test "a Story from another universe is dropped and reported" do
    foreign = filter_for(owner_story_id: stories(:story_two).id)

    assert_not foreign.active?
    assert_equal 1, foreign.discarded.size
    assert_match(/not a story of this universe/, foreign.discarded.first)
    assert_equal [ "Magic costs a memory", "The night crossing" ], apply(foreign).map(&:name)
  end

  test "the reader can choose an order, and each choice still keeps the universe-wide rules first" do
    assert_equal [ "Magic costs a memory", "The night crossing" ], apply(filter_for(sort: "created")).map(&:name),
      "newest first, within each owner group"
    assert_equal [ "Magic costs a memory", "The night crossing" ], apply(filter_for(sort: "updated")).map(&:name),
      "recently edited first, within each owner group"

    # With two story-owned rules, the order inside that group is what the choice
    # really decides.
    later = canon_rules(:canon_rule_two).dup
    later.update!(name: "The daylight crossing", slug: "d3",
      created_at: Time.utc(2026, 2, 5), updated_at: Time.utc(2026, 2, 20))

    assert_equal [ "Magic costs a memory", "The daylight crossing", "The night crossing" ],
      apply(filter_for(sort: "created")).map(&:name)
  end

  test "an order is resolved against an allowlist, so a hand-edited URL cannot choose one" do
    forged = filter_for(sort: "name; DROP TABLE canon_rules")

    assert_equal "name", forged.sort, "an order this list does not offer falls back to the default"
    assert_equal 1, forged.discarded.size
    assert_match(/not one this list offers/, forged.discarded.first)
    assert_equal [ "Magic costs a memory", "The night crossing" ], apply(forged).map(&:name)
  end

  test "a sort narrows nothing, so it is active without being a narrowing" do
    sorted = filter_for(sort: "created")

    assert sorted.active?, "the reader did ask for something"
    assert_not sorted.narrowed?, "but an order cannot select a record or empty a list"
    assert_equal({ sort: "created" }, sorted.query_params)
  end

  test "the default order is never spelled out in the canonical query" do
    assert_empty filter_for.query_params
    assert_equal({}, filter_for(sort: "name").query_params)
    assert_equal({ sort: "created" }, filter_for(sort: "created").query_params)
  end

  test "records that tie on the chosen order keep a stable order across requests" do
    canon_rules(:canon_rule_one).update!(name: "Same name")
    canon_rules(:canon_rule_two).update!(name: "Same name")

    first = apply(filter_for).map(&:id)
    second = apply(filter_for).map(&:id)

    assert_equal first, second, "two readers opening the same link see the same list"
    assert_equal first.sort, second.sort, "the tiebreaker is the id"
  end

  test "filters combine" do
    assert_equal [ "The night crossing" ],
      apply(filter_for(q: "crossed", canon_type: "rule", owner_story_id: stories(:story_one).id)).map(&:name)
    assert_empty apply(filter_for(q: "crossed", canon_type: "locked")).map(&:name)
  end

  test "query_params carries only the filters that are really in effect" do
    assert_equal({ q: "memory" }, filter_for(q: "  memory  ").query_params)
    assert_equal({ canon_type: "locked" }, filter_for(canon_type: "locked").query_params)
    assert_equal({ owner_story_id: stories(:story_one).id.to_s },
      filter_for(owner_story_id: stories(:story_one).id).query_params)
    assert_equal({ owner_story_id: CanonRuleFilter::UNIVERSE_SCOPE },
      filter_for(owner_story_id: CanonRuleFilter::UNIVERSE_SCOPE).query_params)
    assert_equal({ q: "memory", sort: "updated" },
      filter_for(q: "memory", sort: "updated").query_params)
  end

  private
    def filter_for(**params)
      CanonRuleFilter.new(params, stories: @stories)
    end

    def apply(filter)
      filter.apply(@universe.canon_rules).to_a
    end
end
