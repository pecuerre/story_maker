require "test_helper"

class LocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @location = locations(:location_one)
    @location_tag = location_tags(:location_tag_two)
    sign_in_as(users(:user_one))
  end

  # The tree descends one level per row, so a hierarchy deeper than two levels used
  # to ask the database twice per parent row — once to count the children and once
  # to read them — plus once more for each deeper node's tags. What must not happen
  # is the query count following the tree's depth.
  test "a deeper hierarchy does not add queries" do
    shallow = count_queries(/FROM "locations"/) do
      get universe_locations_url(universe_slug: @universe.slug)
    end

    parent = nil
    4.times do |depth|
      parent = @universe.locations.create!(name: "Nested #{depth}", position: 10 + depth, parent: parent)
    end

    deep = count_queries(/FROM "locations"/) do
      get universe_locations_url(universe_slug: @universe.slug)
    end

    assert_response :success
    assert_equal shallow, deep
    # The deepest row is on the page, so the count cannot be flat because nothing
    # was rendered.
    assert_select ".taxonomy-node", minimum: 4
  end

  test "should get index with location tag options" do
    get universe_locations_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Locations"
    assert_includes response.body, "Location tag"
    assert_includes response.body, @location.name
  end

  test "should create location as json" do
    assert_difference("Location.count") do
      post universe_locations_url(universe_slug: @universe.slug),
        params: { location: { name: "New location", description: "A description", location_tag_ids: [ @location_tag.id ] } },
        as: :json
    end

    assert_response :created
    assert_equal [ @location_tag.id ], response.parsed_body["location_tag_ids"]
    assert_equal "A description", Location.order(:id).last.description
  end

  test "should create a location without tags" do
    assert_difference("Location.count") do
      post universe_locations_url(universe_slug: @universe.slug),
        params: { location: { name: "Untagged location" } },
        as: :json
    end

    assert_response :created
    assert_empty response.parsed_body["location_tag_ids"]
    assert_empty Location.order(:id).last.location_tags
  end

  test "should reject location tags from another universe" do
    foreign_tag = location_tags(:location_tag_three)
    join_count = -> { ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM locations_location_tags") }

    assert_no_difference([ "Location.count", join_count ]) do
      post universe_locations_url(universe_slug: @universe.slug),
        params: { location: { name: "Mis-scoped location", location_tag_ids: [ foreign_tag.id ] } },
        as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "must belong to the same universe" ], response.parsed_body["location_tags"]
  end

  test "the location delete confirmation states that scenes and other records remain" do
    get universe_locations_url(universe_slug: @universe.slug)

    assert_response :success
    # The tree sends the confirmation to the browser as a per-node attribute, so it
    # is read from the DOM rather than from a rendered button. The mandatory
    # consequence copy is carried by that attribute and must not be weakened.
    assert_select "li.taxonomy-node[data-confirm-message=?]",
      "Delete “#{@location.name}”? Its descendant locations, tag assignments, and links to scenes " \
      "will be permanently removed. Scenes and other universe records will remain."
  end

  test "should update location details as json" do
    patch universe_location_url(universe_slug: @universe.slug, id: @location),
      params: { location: { name: "Renamed", description: "Updated", location_tag_ids: [ @location_tag.id ] } },
      as: :json

    assert_response :success
    @location.reload
    assert_equal [ "Renamed", "Updated", [ @location_tag.id ] ], [ @location.name, @location.description, @location.location_tag_ids ]
  end

  # The filter, and the three empty states. `LocationFilterTest` covers the
  # value object; what only a request can show is the page around it — the
  # canonical URL, what the filter does to rows, and that a tag the editor
  # cannot assign still narrows to the records that carry it.
  test "index renders a search area that narrows and stays in the URL" do
    Location.create!(universe: @universe, name: "Ravenscar", description: "A keep on the coast")

    get universe_locations_url(universe_slug: @universe.slug, q: "Raven")

    assert_response :success
    assert_select "form[action=?][method=?]", universe_locations_path(universe_slug: @universe.slug), "get" do
      assert_select "input[name=q][value=?]", "Raven"
    end
    assert_select ".taxonomy-tree-filter", text: /Showing 1 location of 3 locations/
    assert_select ".taxonomy-node", count: 1
  end

  test "index filters by a location tag, including a grouping tag the editor cannot assign" do
    # `location_tag_two` is `taggable: false`, so the modal omits it, and
    # `location_two` already carries one. Validating the filter against the
    # editor's list would drop a tag that is really in effect.
    assert_not location_tags(:location_tag_two).taggable?

    get universe_locations_url(universe_slug: @universe.slug, location_tag_id: location_tags(:location_tag_two).id)

    assert_response :success
    assert_select ".taxonomy-node", count: 1
    assert_select "select[name=location_tag_id] option[selected][value=?]", location_tags(:location_tag_two).id
  end

  test "index redirects a form submission to the canonical filter query" do
    get universe_locations_url(universe_slug: @universe.slug, q: "Mist", location_tag_id: "", sort: "")

    assert_redirected_to universe_locations_url(universe_slug: @universe.slug, q: "Mist")
  end

  test "index reports a location tag it could not use instead of showing an empty list" do
    get universe_locations_url(universe_slug: @universe.slug, location_tag_id: location_tags(:location_tag_three).id)

    assert_response :success
    assert_select ".flash-alert, .alert", text: /not a location tag of this universe/
    assert_select ".taxonomy-node", count: 2
  end

  test "index separates a filtered empty result from a universe without locations" do
    get universe_locations_url(universe_slug: @universe.slug, q: "no such location")

    assert_response :success
    assert_select ".empty-title", text: "Nothing matches these filters"
    assert_select ".empty-description",
      text: /2 locations in this universe, but none of them match the filters above/
    assert_select ".empty-state .badge", text: /Search: “no such location”/
    assert_select ".empty-state a", text: "Clear filters"
  end

  test "a guest can filter and sees no mutation control" do
    sign_out

    get universe_locations_url(universe_slug: @universe.slug, q: "Location one")

    assert_response :success
    assert_select ".taxonomy-node", count: 1
    assert_select "[data-controller='taxonomy-tree']", count: 0
    assert_select ".taxonomy-tree-filter input[name=q]", minimum: 1
  end
end
