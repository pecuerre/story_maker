require "test_helper"

# The Ownerships list filter is a value object, and it is worth covering on its
# own because the request tests can only show the outcome, not which part of the
# query produced it, what it did with a value it could not use, or which order a
# choice really took.
#
# It is the second filter whose text has to reach **past** the record, and the one
# whose composed label is a *translated sentence*: `"X owns Y"` is chrome, not a
# stored string, so the search reaches the character and the item names and never
# the sentence itself.
class OwnershipFilterTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @ownership_tags = @universe.ownership_tags.reorder(:position, :id).to_a
    @item_one = items(:item_one)
    @item_two = items(:item_two)
    @character_one = characters(:character_one)
    @character_three = characters(:character_three)

    ownerships(:ownership_one).update!(created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 3, 1))
    @ownership_one = ownerships(:ownership_one)
    @ownership_two = Ownership.create!(universe: @universe, character: @character_three, item: @item_two,
      created_at: Time.utc(2026, 2, 1), updated_at: Time.utc(2026, 2, 10))
  end

  test "an empty filter changes nothing, orders by name, and reports itself inactive" do
    filter = filter_for

    assert_not filter.active?
    assert_not filter.narrowed?
    assert_empty filter.query_params
    assert_empty filter.discarded
    assert_equal "name", filter.sort
    assert_equal [ @ownership_one, @ownership_two ], apply(filter)
  end

  test "free text matches the item and the character that make up the label" do
    assert_equal [ @ownership_one ], apply(filter_for(q: "Item one"))
    assert_equal [ @ownership_two ], apply(filter_for(q: "Item two"))
    assert_equal [ @ownership_two ], apply(filter_for(q: "Character three"))
  end

  test "the composed sentence is not searchable, in any language" do
    # `display_label` is translated chrome, and matching the words of one
    # language's sentence would be a search that silently means something only
    # there. The two names are what a reader types.
    assert_empty apply(filter_for(q: "owns"))
  end

  test "free text matches the ownership's own name and description, ignoring case" do
    @ownership_two.update!(name: "Heirloom", description: "Kept in the vault")

    assert_equal [ @ownership_two ], apply(filter_for(q: "heirloom"))
    assert_equal [ @ownership_two ], apply(filter_for(q: "VAULT"))
  end

  test "search text is matched literally, so a wildcard is not a wildcard" do
    @ownership_one.update!(name: "100% of the hold")

    assert_equal [ @ownership_one ], apply(filter_for(q: "100%"))
    assert_equal [ @ownership_one ], apply(filter_for(q: "%")),
      "a percent sign is text to find, not a pattern matching every ownership"
  end

  test "a tag is not searchable text" do
    assert_empty apply(filter_for(q: "Ownership tag one"))
  end

  test "the tag filter narrows to the records carrying a tag" do
    assert_equal [ @ownership_one ],
      apply(filter_for(ownership_tag_id: ownership_tags(:ownership_tag_one).id))
  end

  test "a grouping tag is filterable even though the editor cannot assign it" do
    assert_not ownership_tags(:ownership_tag_two).taggable?
    @ownership_two.update!(ownership_tags: [ ownership_tags(:ownership_tag_two) ])

    assert_equal [ @ownership_two ],
      apply(filter_for(ownership_tag_id: ownership_tags(:ownership_tag_two).id))
  end

  test "a tag that is not in this universe is dropped and reported" do
    foreign = filter_for(ownership_tag_id: ownership_tags(:ownership_tag_three).id)

    assert_not foreign.active?
    assert_equal 1, foreign.discarded.size
    assert_match(/not an ownership tag of this universe/, foreign.discarded.first)
    assert_equal [ @ownership_one, @ownership_two ], apply(foreign)
  end

  test "the reader can choose an order, and each choice really reorders the list" do
    assert_equal [ @ownership_two, @ownership_one ], apply(filter_for(sort: "created")),
      "newest first"
    assert_equal [ @ownership_one, @ownership_two ], apply(filter_for(sort: "updated")),
      "recently edited first"
  end

  test "an order is resolved against an allowlist, so a hand-edited URL cannot choose one" do
    forged = filter_for(sort: "name; DROP TABLE ownerships")

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
    @ownership_one.update!(name: "Same name")
    @ownership_two.update!(name: "Same name")

    first = apply(filter_for).map(&:id)
    second = apply(filter_for).map(&:id)

    assert_equal first, second, "two readers opening the same link see the same list"
    assert_equal first.sort, second.sort, "the tiebreaker is the id"
  end

  test "a sort is a read, never a write" do
    before = @universe.ownerships.pluck(:id, :updated_at).to_h

    filter_for(sort: "created").apply(@universe.ownerships).to_a

    assert_equal before, @universe.ownerships.pluck(:id, :updated_at).to_h,
      "choosing an order is a read, never a write"
  end

  test "filters combine, and the chosen order still wins" do
    @ownership_two.update!(name: "Search hit")

    assert_equal [ @ownership_one ], apply(filter_for(q: "Item one"))
    assert_equal [ @ownership_two ], apply(filter_for(q: "Search hit"))
    assert_equal [ @ownership_two, @ownership_one ], apply(filter_for(q: "Item", sort: "created"))
  end

  test "query_params carries only the filters that are really in effect" do
    assert_equal({ q: "vault" }, filter_for(q: "  vault  ").query_params)
    assert_equal({ ownership_tag_id: ownership_tags(:ownership_tag_one).id.to_s },
      filter_for(ownership_tag_id: ownership_tags(:ownership_tag_one).id).query_params)
    assert_equal({ q: "vault", sort: "updated" }, filter_for(q: "vault", sort: "updated").query_params)
  end

  private
    def filter_for(**params)
      OwnershipFilter.new(params, ownership_tags: @ownership_tags)
    end

    def apply(filter)
      filter.apply(@universe.ownerships).to_a
    end
end
