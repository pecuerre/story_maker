require "test_helper"

# The Items list filter is a value object, and it is worth covering on its own
# because the request tests can only show the outcome, not which part of the
# query produced it, what it did with a value it could not use, or which order
# a choice really took. Like the Characters filter, it is the second filter on
# a **flat** list, so its own rules are pinned here rather than in the shared
# contract's test: an order that reaches the query unvalidated, an order that is
# never written, and an order that is not deterministic are all failures here.
class ItemFilterTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @item_tags = @universe.item_tags.reorder(:position, :id).to_a

    # Fixed timestamps, because "newest first" and "recently edited first" are
    # only meaningful when the fixtures are not all stamped within the same
    # microsecond of each other by the fixture loader. `item_one` was created
    # first but edited last, so the two orders really do differ.
    items(:item_one).update!(created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 3, 1))
    items(:item_two).update!(created_at: Time.utc(2026, 2, 1), updated_at: Time.utc(2026, 2, 10))

    @item_one = items(:item_one)
    @item_two = items(:item_two)
  end

  test "an empty filter changes nothing, orders by name, and reports itself inactive" do
    filter = filter_for

    assert_not filter.active?
    assert_not filter.narrowed?
    assert_empty filter.query_params
    assert_empty filter.discarded
    assert_equal "name", filter.sort
    assert_equal [ "Item one", "Item two" ], apply(filter).map(&:name)
  end

  test "free text matches the name or the description, ignoring case" do
    @item_one.update!(description: "The keeper of the gate")

    assert_equal [ "Item one" ], apply(filter_for(q: "keeper")).map(&:name)
    assert_equal [ "Item one" ], apply(filter_for(q: "KEEPER")).map(&:name), "a search box ignores case"
    assert_equal [ "Item two" ], apply(filter_for(q: "Item two")).map(&:name)
    assert_empty apply(filter_for(q: "Item tag one")).map(&:name), "a tag is not searchable text"
  end

  test "free text matches every profile answer, not only the name and description" do
    # Reading `Item::PROFILE_FIELDS` rather than a written list is what keeps a
    # new profile column findable; `item_one` already carries a full profile.
    Item::PROFILE_FIELDS.each do |field|
      @item_one.update_column(field, "hidden #{field} answer")
    end

    Item::PROFILE_FIELDS.each do |field|
      assert_equal [ "Item one" ], apply(filter_for(q: "hidden #{field} answer")).map(&:name),
        "#{field} is not part of the text filter"
    end
  end

  test "search text is matched literally, so a wildcard is not a wildcard" do
    @item_one.update!(name: "100% of the oath")

    assert_equal [ "100% of the oath" ], apply(filter_for(q: "100%")).map(&:name)
    assert_equal [ "100% of the oath" ], apply(filter_for(q: "%")).map(&:name),
      "a percent sign is text to search for, not a pattern matching everything"
  end

  test "the tag filter narrows to the records carrying a tag" do
    assert_equal [ "Item one" ], apply(filter_for(item_tag_id: item_tags(:item_tag_one).id)).map(&:name),
      "the records carrying a tag are the ones shown, not the ones below it"
  end

  test "a grouping tag is filterable even though the editor cannot assign it" do
    # `item_tag_two` is `taggable: false`, so the modal's picker omits it, and
    # `item_two` already carries one. Validating the filter against the editor's
    # list would drop a tag that is really in effect.
    assert_not item_tags(:item_tag_two).taggable?
    assert_equal [ "Item two" ], apply(filter_for(item_tag_id: item_tags(:item_tag_two).id)).map(&:name)
  end

  test "a tag that is not in this universe is dropped and reported" do
    foreign = filter_for(item_tag_id: item_tags(:item_tag_three).id)

    assert_not foreign.active?
    assert_equal 1, foreign.discarded.size
    assert_match(/not an item tag of this universe/, foreign.discarded.first)
    assert_equal [ "Item one", "Item two" ], apply(foreign).map(&:name)
  end

  test "the reader can choose an order, and each choice really reorders the list" do
    assert_equal [ "Item two", "Item one" ], apply(filter_for(sort: "created")).map(&:name),
      "newest first"
    assert_equal [ "Item one", "Item two" ], apply(filter_for(sort: "updated")).map(&:name),
      "recently edited first"
  end

  test "an order is resolved against an allowlist, so a hand-edited URL cannot choose one" do
    forged = filter_for(sort: "name; DROP TABLE items")

    assert_equal "name", forged.sort, "an order this list does not offer falls back to the default"
    assert_equal 1, forged.discarded.size
    assert_match(/not one this list offers/, forged.discarded.first)
    assert_equal [ "Item one", "Item two" ], apply(forged).map(&:name)
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
    @item_one.update!(name: "Same name")
    @item_two.update!(name: "Same name")

    first = apply(filter_for).map(&:id)
    second = apply(filter_for).map(&:id)

    assert_equal first, second, "two readers opening the same link see the same list"
    assert_equal first.sort, second.sort, "the tiebreaker is the id"
  end

  test "a sort never renumbers anything" do
    positions = @universe.items.pluck(:id, :position).to_h

    filter_for(sort: "created").apply(@universe.items).to_a

    assert_equal positions, @universe.items.pluck(:id, :position).to_h,
      "choosing an order is a read, never a write"
  end

  test "filters combine, and the chosen order still wins" do
    @item_one.update!(name: "The first object")
    @item_two.update!(description: "The second object")

    assert_equal [ "The first object" ], apply(filter_for(q: "first object", sort: "name")).map(&:name)
    assert_equal [ "Item two" ], apply(filter_for(q: "second object", sort: "name")).map(&:name),
      "the description is searched, and the name is what the row shows"
    assert_equal [ "Item two", "The first object" ], apply(filter_for(q: "object", sort: "created")).map(&:name)
  end

  test "query_params carries only the filters that are really in effect" do
    assert_equal({ q: "keeper" }, filter_for(q: "  keeper  ").query_params)
    assert_equal({ item_tag_id: item_tags(:item_tag_one).id.to_s },
      filter_for(item_tag_id: item_tags(:item_tag_one).id).query_params)
    assert_equal({ q: "keeper", sort: "updated" }, filter_for(q: "keeper", sort: "updated").query_params)
  end

  private
    def filter_for(**params)
      ItemFilter.new(params, item_tags: @item_tags)
    end

    def apply(filter)
      filter.apply(@universe.items).to_a
    end
end
