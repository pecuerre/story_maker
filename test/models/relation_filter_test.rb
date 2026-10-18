require "test_helper"

# The Relations list filter is a value object, and it is worth covering on its
# own because the request tests can only show the outcome, not which part of the
# query produced it, what it did with a value it could not use, or which order a
# choice really took.
#
# It is the first filter whose text has to reach **past** the record: a Relation's
# label is the two characters, not the optional name, so a search for a character
# is the case the shared `narrowed_by_text` cannot answer.
class RelationFilterTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @relation_tags = @universe.relation_tags.reorder(:position, :id).to_a
    @character_one = characters(:character_one)
    @character_two = characters(:character_two)
    @character_three = characters(:character_three)

    # Fixed timestamps, because "newest first" and "recently edited first" are
    # only meaningful when the fixtures are not all stamped within the same
    # microsecond of each other by the fixture loader. `relation_one` was created
    # first but edited last, so the two orders really do differ.
    relations(:relation_one).update!(created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 3, 1))
    @relation_one = relations(:relation_one)
    @relation_two = Relation.create!(universe: @universe, character1: @character_three,
      character2: @character_two, created_at: Time.utc(2026, 2, 1), updated_at: Time.utc(2026, 2, 10))
  end

  test "an empty filter changes nothing, orders by name, and reports itself inactive" do
    filter = filter_for

    assert_not filter.active?
    assert_not filter.narrowed?
    assert_empty filter.query_params
    assert_empty filter.discarded
    assert_equal "name", filter.sort
    # Both relations are unnamed, so both sort under an empty name and the id
    # tiebreaker keeps the creation order the list already had.
    assert_equal [ @relation_one, @relation_two ], apply(filter)
  end

  test "free text matches the name of either endpoint" do
    assert_equal [ @relation_one ], apply(filter_for(q: "Character one"))
    assert_equal [ @relation_two ], apply(filter_for(q: "Character three"))
    assert_equal [ @relation_one, @relation_two ], apply(filter_for(q: "Character two")).sort_by(&:id),
      "both relations have `character_two` as an endpoint"
  end

  test "free text matches the relation's own name and description, ignoring case" do
    @relation_two.update!(name: "Bitter rivals", description: "They were friends once")

    assert_equal [ @relation_two ], apply(filter_for(q: "bitter"))
    assert_equal [ @relation_two ], apply(filter_for(q: "FRIENDS"))
  end

  test "search text is matched literally, so a wildcard is not a wildcard" do
    @relation_one.update!(name: "100% of the oath")

    assert_equal [ @relation_one ], apply(filter_for(q: "100%"))
    assert_equal [ @relation_one ], apply(filter_for(q: "%")),
      "a percent sign is text to find, not a pattern matching every relation"
  end

  test "a tag is not searchable text" do
    assert_empty apply(filter_for(q: "Relation tag one"))
  end

  test "the tag filter narrows to the records carrying a tag" do
    assert_equal [ @relation_one ],
      apply(filter_for(relation_tag_id: relation_tags(:relation_tag_one).id))
  end

  test "a grouping tag is filterable even though the editor cannot assign it" do
    # `relation_tag_two` is `taggable: false`, so the modal's picker omits it.
    # Validating the filter against the editor's list would drop a tag that is
    # really in effect on a record.
    assert_not relation_tags(:relation_tag_two).taggable?
    @relation_two.update!(relation_tags: [ relation_tags(:relation_tag_two) ])

    assert_equal [ @relation_two ],
      apply(filter_for(relation_tag_id: relation_tags(:relation_tag_two).id))
  end

  test "a tag that is not in this universe is dropped and reported" do
    foreign = filter_for(relation_tag_id: relation_tags(:relation_tag_three).id)

    assert_not foreign.active?
    assert_equal 1, foreign.discarded.size
    assert_match(/not a relation tag of this universe/, foreign.discarded.first)
    assert_equal [ @relation_one, @relation_two ], apply(foreign)
  end

  test "the reader can choose an order, and each choice really reorders the list" do
    assert_equal [ @relation_two, @relation_one ], apply(filter_for(sort: "created")),
      "newest first"
    assert_equal [ @relation_one, @relation_two ], apply(filter_for(sort: "updated")),
      "recently edited first"
  end

  test "an order is resolved against an allowlist, so a hand-edited URL cannot choose one" do
    forged = filter_for(sort: "name; DROP TABLE relations")

    assert_equal "name", forged.sort, "an order this list does not offer falls back to the default"
    assert_equal 1, forged.discarded.size
    assert_match(/not one this list offers/, forged.discarded.first)
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
    @relation_one.update!(name: "Same name")
    @relation_two.update!(name: "Same name")

    first = apply(filter_for).map(&:id)
    second = apply(filter_for).map(&:id)

    assert_equal first, second, "two readers opening the same link see the same list"
    assert_equal first.sort, second.sort, "the tiebreaker is the id"
  end

  test "a sort is a read, never a write" do
    before = @universe.relations.pluck(:id, :updated_at).to_h

    filter_for(sort: "created").apply(@universe.relations).to_a

    assert_equal before, @universe.relations.pluck(:id, :updated_at).to_h,
      "choosing an order is a read, never a write"
  end

  test "filters combine, and the chosen order still wins" do
    @relation_two.update!(name: "Search hit")

    assert_equal [ @relation_one ], apply(filter_for(q: "Character one"))
    assert_equal [ @relation_two ], apply(filter_for(q: "Search hit"))
    assert_equal [ @relation_two, @relation_one ], apply(filter_for(q: "Character", sort: "created"))
  end

  test "query_params carries only the filters that are really in effect" do
    assert_equal({ q: "rivals" }, filter_for(q: "  rivals  ").query_params)
    assert_equal({ relation_tag_id: relation_tags(:relation_tag_one).id.to_s },
      filter_for(relation_tag_id: relation_tags(:relation_tag_one).id).query_params)
    assert_equal({ q: "rivals", sort: "updated" }, filter_for(q: "rivals", sort: "updated").query_params)
  end

  private
    def filter_for(**params)
      RelationFilter.new(params, relation_tags: @relation_tags)
    end

    def apply(filter)
      filter.apply(@universe.relations).to_a
    end
end
