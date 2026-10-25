require "test_helper"

class FactionTagFilterTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
  end

  test "narrows by name and description without changing hierarchy order" do
    filter = FactionTagFilter.new(q: "factions")

    assert_equal({ q: "factions" }, filter.query_params)
    assert_equal [ "Faction tag one" ], filter.apply(@universe.faction_tags).map(&:name)
  end

  test "drops blank query text from its canonical query" do
    assert_equal({}, FactionTagFilter.new(q: "  ").query_params)
  end
end
