require "test_helper"

# The Characters list filter is a value object: it is worth covering on its own
# because the request tests can only show the outcome, not which part of the
# query produced it or what it did with a value it could not use.
#
# It is also the only filter on a **flat** list and the only one a reader can
# sort, so the sort rules are pinned here rather than in the shared contract's
# test: an order that reaches the query unvalidated, an order that is never
# written, and an order that is not deterministic are all failures of this
# class.
class CharacterFilterTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @character_tags = @universe.character_tags.reorder(:position, :id).to_a

    # Fixed timestamps, because "newest first" and "recently edited first" are
    # only meaningful when the fixtures are not all stamped within the same
    # microsecond of each other by the fixture loader.
    characters(:character_one).update!(created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 3, 1))
    characters(:character_two).update!(created_at: Time.utc(2026, 2, 1), updated_at: Time.utc(2026, 4, 1))
    characters(:character_three).update!(created_at: Time.utc(2026, 3, 1), updated_at: Time.utc(2026, 2, 1))

    @character_one = characters(:character_one)
    @character_two = characters(:character_two)
    @character_three = characters(:character_three)
  end

  test "an empty filter changes nothing, orders by name, and reports itself inactive" do
    filter = filter_for

    assert_not filter.active?
    assert_not filter.narrowed?
    assert_empty filter.query_params
    assert_empty filter.discarded
    assert_equal "name", filter.sort
    assert_equal [ "Character one", "Character three", "Character two" ], apply(filter).map(&:name)
  end

  test "free text matches the name or any profile field, ignoring case" do
    @character_one.update!(wants: "The keeper of the gate")

    assert_equal [ @character_one ], apply(filter_for(q: "keeper"))
    assert_equal [ @character_one ], apply(filter_for(q: "KEEPER")), "a search box ignores case"
    assert_equal [ @character_three ], apply(filter_for(q: "Character three"))
    assert_empty apply(filter_for(q: "Character tag one")), "a tag is not searchable text"
  end

  test "free text also searches the other structured profile fields" do
    @character_one.update!(
      needs: "a lantern", lies_to_self: "the bridge is safe", contradictions: "brave but cautious",
      under_pressure_they: "runs toward danger", never: "leave a friend behind"
    )

    %w[lantern bridge cautious danger friend].each do |term|
      assert_equal [ @character_one ], apply(filter_for(q: term)), "#{term} should match the Character profile"
    end
  end

  test "search text is matched literally, so a wildcard is not a wildcard" do
    @character_one.update!(name: "100% of the oath")

    assert_equal [ "100% of the oath" ], apply(filter_for(q: "100%")).map(&:name)
    assert_equal [ "100% of the oath" ], apply(filter_for(q: "%")).map(&:name),
      "a percent sign is text to search for, not a pattern matching everything"
  end

  test "the tag filter narrows through the tag's own records, parents included or not" do
    assert_equal [ @character_one ], apply(filter_for(character_tag_id: character_tags(:character_tag_one).id))
    assert_equal [ @character_three ], apply(filter_for(character_tag_id: character_tags(:character_tag_child).id)),
      "a parent tag narrows to the records carrying it, not the records below it"
  end

  test "a grouping tag is filterable even though the editor cannot assign it" do
    # `character_tag_two` is `taggable: false`, so the modal's picker omits it,
    # and `character_two` already carries one. Validating the filter against the
    # editor's list would drop a tag that is really in effect.
    assert_not character_tags(:character_tag_two).taggable?
    assert_equal [ @character_two ], apply(filter_for(character_tag_id: character_tags(:character_tag_two).id))
  end

  test "a tag that is not in this universe is dropped and reported" do
    foreign = filter_for(character_tag_id: character_tags(:character_tag_three).id)

    assert_not foreign.active?
    assert_equal 1, foreign.discarded.size
    assert_match(/not a character tag of this universe/, foreign.discarded.first)
    assert_equal [ "Character one", "Character three", "Character two" ], apply(foreign).map(&:name)
  end

  test "the reader can choose an order, and each choice really reorders the list" do
    assert_equal [ "Character three", "Character two", "Character one" ], apply(filter_for(sort: "created")).map(&:name)
    assert_equal [ "Character two", "Character one", "Character three" ], apply(filter_for(sort: "updated")).map(&:name)
  end

  test "an order is resolved against an allowlist, so a hand-edited URL cannot choose one" do
    forged = filter_for(sort: "name; DROP TABLE characters")

    assert_equal "name", forged.sort, "an order this list does not offer falls back to the default"
    assert_equal 1, forged.discarded.size
    assert_match(/not one this list offers/, forged.discarded.first)
    assert_equal [ "Character one", "Character three", "Character two" ], apply(forged).map(&:name)
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
    @character_two.update!(name: "Same name")
    @character_three.update!(name: "Same name")

    first = apply(filter_for).map(&:id)
    second = apply(filter_for).map(&:id)

    assert_equal first, second, "two readers opening the same link see the same list"
    assert_equal first.sort, second.sort, "the tiebreaker is the id, which is the same order the sort returns"
  end

  test "a sort never renumbers anything" do
    positions = @universe.characters.pluck(:id, :position).to_h

    filter_for(sort: "created").apply(@universe.characters).to_a

    assert_equal positions, @universe.characters.pluck(:id, :position).to_h,
      "choosing an order is a read, never a write"
  end

  test "filters combine, and the chosen order still wins" do
    @character_one.update!(name: "The first keeper")
    @character_two.update!(name: "The second keeper")

    assert_equal [ "The first keeper", "The second keeper" ],
      apply(filter_for(q: "keeper", sort: "name")).map(&:name)
    assert_equal [ "The second keeper", "The first keeper" ],
      apply(filter_for(q: "keeper", sort: "created")).map(&:name)
  end

  test "query_params carries only the filters that are really in effect" do
    assert_equal({ q: "keeper" }, filter_for(q: "  keeper  ").query_params)
    assert_equal({ character_tag_id: character_tags(:character_tag_one).id.to_s },
      filter_for(character_tag_id: character_tags(:character_tag_one).id).query_params)
    assert_equal({ q: "keeper", sort: "updated" }, filter_for(q: "keeper", sort: "updated").query_params)
  end

  test "every order the list offers has a label, and every label an order" do
    offered = CharacterFilter.sort_values.map(&:to_s)
    # `I18n.t` symbolizes a hash's keys, so the labels are compared as strings.
    labelled = I18n.t("characters.filter.sort_options", default: {}).keys.map(&:to_s)

    assert_equal offered.sort, labelled.sort,
      "a key with no order clause renders a blank option, and a label with no order is a dead control"
    assert_includes offered, CharacterFilter::DEFAULT_SORT, "the default order has to be one a reader can pick back to"
  end

  private
    def filter_for(**params)
      CharacterFilter.new(params, character_tags: @character_tags)
    end

    def apply(filter)
      filter.apply(@universe.characters).to_a
    end
end
