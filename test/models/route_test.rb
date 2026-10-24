require "test_helper"

class RouteTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @from = locations(:location_one)
    @to = locations(:location_two)
  end

  test "requires both endpoint locations" do
    route = Route.new(universe: @universe)

    assert_not route.valid?
    assert_includes route.errors[:from_location], "can't be blank"
    assert_includes route.errors[:to_location], "can't be blank"
  end

  test "requires both endpoint locations to belong to its universe" do
    route = Route.new(universe: @universe, from_location: @from,
      to_location: locations(:location_three))

    assert_not route.valid?
    assert_includes route.errors[:to_location], "must belong to the route's universe"

    swapped = Route.new(universe: @universe, from_location: locations(:location_three), to_location: @to)
    assert_not swapped.valid?
    assert_includes swapped.errors[:from_location], "must belong to the route's universe"
  end

  test "uses a name when present and otherwise labels the directed endpoints" do
    route = Route.create!(universe: @universe, from_location: @from, to_location: @to)

    assert_equal "#{@from.name} → #{@to.name}", route.display_string
    assert_equal "#{@from.slug}-#{@to.slug}", route.slug

    route.update!(name: "The King's Road")
    assert_equal "The King's Road", route.display_string
    assert_equal "the-king-s-road", route.slug
  end

  test "stores free-form distance and duration values" do
    route = Route.create!(universe: @universe, from_location: @from, to_location: @to,
      distance: "three days' ride", duration: "until sundown")

    assert_equal "three days' ride", route.distance
    assert_equal "until sundown", route.duration
  end

  test "soft deleting a location cascades to its routes, and restoring it restores them" do
    route = Route.create!(universe: @universe, from_location: @from, to_location: @to)

    @from.soft_delete

    assert_predicate route.reload, :deleted?

    @from.restore

    assert_predicate route.reload, :deleted?, "restoring an endpoint does not implicitly restore dependents"

    route.restore

    assert_not route.reload.deleted?
  end
end
