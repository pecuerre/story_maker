require "test_helper"

# The Locations list filter is a value object, and it is worth covering on its
# own because the request tests can only show the outcome, not which part of the
# query produced it or what it did with a value it could not use. It is the
# first filter on a **tree**, so it has no `SORTS`: a tree is drag-sorted on
# `position`, and a reader-chosen order would show a sequence the drag control
# contradicts.
class LocationFilterTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @location_tags = @universe.location_tags.reorder(:position, :id).to_a

    @location_one = locations(:location_one)
    @location_two = locations(:location_two)
  end

  test "an empty filter changes nothing, keeps the drag order, and reports itself inactive" do
    filter = filter_for

    assert_not filter.active?
    assert_not filter.narrowed?
    assert_empty filter.query_params
    assert_empty filter.discarded
    assert_not LocationFilter.sortable?
    assert_nil filter.sort
    assert_equal Set.new([ "Location one", "Location two" ]), Set.new(apply(filter).map(&:name))
  end

  test "free text matches the name, the description, or a profile answer, ignoring case" do
    @location_one.update!(description: "A keep on the coast", sensory_smell: "Pipeweed and rain")

    assert_equal [ "Location one" ], apply(filter_for(q: "keep")).map(&:name)
    assert_equal [ "Location one" ], apply(filter_for(q: "KEEP")).map(&:name),
      "a search box ignores case"
    assert_equal [ "Location one" ], apply(filter_for(q: "pipeweed")).map(&:name),
      "a reader may remember only what the place smelled like"
    assert_equal [ "Location two" ], apply(filter_for(q: "Location two")).map(&:name)
    assert_empty apply(filter_for(q: "Location tag one")).map(&:name),
      "a tag is not searchable text"
  end

  test "search text is matched literally, so a wildcard is not a wildcard" do
    @location_one.update!(name: "100% of the map")

    assert_equal [ "100% of the map" ], apply(filter_for(q: "100%")).map(&:name)
    assert_equal [ "100% of the map" ], apply(filter_for(q: "%")).map(&:name),
      "a percent sign is text to search for, not a pattern matching everything"
  end

  test "the tag filter narrows to the records carrying a tag" do
    assert_equal [ "Location one" ], apply(filter_for(location_tag_id: location_tags(:location_tag_one).id)).map(&:name),
      "the records carrying a tag are the ones shown, not the ones below it"
  end

  test "a grouping tag is filterable even though the editor cannot assign it" do
    # `location_tag_two` is `taggable: false`, so the modal's picker omits it,
    # and `location_two` already carries one. Validating the filter against the
    # editor's list would drop a tag that is really in effect.
    assert_not location_tags(:location_tag_two).taggable?
    assert_equal [ "Location two" ], apply(filter_for(location_tag_id: location_tags(:location_tag_two).id)).map(&:name)
  end

  test "a tag that is not in this universe is dropped and reported" do
    foreign = filter_for(location_tag_id: location_tags(:location_tag_three).id)

    assert_not foreign.active?
    assert_equal 1, foreign.discarded.size
    assert_match(/not a location tag of this universe/, foreign.discarded.first)
    assert_equal Set.new([ "Location one", "Location two" ]), Set.new(apply(foreign).map(&:name))
  end

  test "an order is never offered, so a hand-edited sort key cannot reach the query" do
    forged = filter_for(sort: "name")

    assert_not forged.active?
    assert_not forged.narrowed?
    assert_nil forged.sort
    assert_empty forged.discarded
    assert_equal Set.new([ "Location one", "Location two" ]), Set.new(apply(forged).map(&:name)),
      "a tree keeps the order it was dragged in"
  end

  test "filters combine" do
    @location_one.update!(name: "The first place")

    assert_equal [ "The first place" ], apply(filter_for(q: "first place")).map(&:name)
    assert_equal [ "Location two" ], apply(filter_for(location_tag_id: location_tags(:location_tag_two).id)).map(&:name)
    assert_empty apply(filter_for(q: "first place", location_tag_id: location_tags(:location_tag_two).id)).map(&:name)
  end

  test "query_params carries only the filters that are really in effect" do
    assert_equal({ q: "keeper" }, filter_for(q: "  keeper  ").query_params)
    assert_equal({ location_tag_id: location_tags(:location_tag_one).id.to_s },
      filter_for(location_tag_id: location_tags(:location_tag_one).id).query_params)
    assert_equal({ q: "keeper", location_tag_id: location_tags(:location_tag_two).id.to_s },
      filter_for(q: "keeper", location_tag_id: location_tags(:location_tag_two).id).query_params)
    assert_equal({}, filter_for(sort: "name").query_params)
  end

  private
    def filter_for(**params)
      LocationFilter.new(params, location_tags: @location_tags)
    end

    def apply(filter)
      filter.apply(@universe.locations).to_a
    end
end
