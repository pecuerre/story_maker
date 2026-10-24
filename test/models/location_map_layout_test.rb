require "test_helper"

class LocationMapLayoutTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
  end

  test "places children to the right of their parent and preserves hierarchy edges" do
    parent = @universe.locations.create!(name: "North country")
    first = @universe.locations.create!(name: "First town", parent: parent, position: 0)
    second = @universe.locations.create!(name: "Second town", parent: parent, position: 1)

    layout = LocationMapLayout.new(locations: [ second, parent, first ], routes: [])
    parent_node = layout.nodes.find { |node| node.location == parent }
    first_node = layout.nodes.find { |node| node.location == first }

    assert_operator first_node.x, :>, parent_node.x
    assert_equal [ first, second ].sort_by(&:id), layout.hierarchy_edges.map(&:record).sort_by(&:id)
    assert_equal [ parent.id, parent.id ], layout.hierarchy_edges.map { |edge| edge.source.location.id }.sort
    assert_equal [ first.id, second.id ], layout.hierarchy_edges.map { |edge| edge.target.location.id }.sort
    assert layout.hierarchy_edges.all? { |edge| edge.path.start_with?("M ") }
  end

  test "route edges retain their direction across different branches" do
    west = @universe.locations.create!(name: "West region")
    west_town = @universe.locations.create!(name: "West town", parent: west)
    east = @universe.locations.create!(name: "East region")
    east_town = @universe.locations.create!(name: "East town", parent: east)
    route = @universe.routes.create!(from_location: west_town, to_location: east_town, name: "Cross-country road")

    layout = LocationMapLayout.new(locations: [ west, west_town, east, east_town ], routes: [ route ])
    edge = layout.route_edges.fetch(0)

    assert_equal route, edge.record
    assert_equal west_town, edge.source.location
    assert_equal east_town, edge.target.location
    assert_equal :route, edge.kind
    assert_includes edge.path, edge.source.right.to_s
    assert_includes edge.path, edge.target.right.to_s
  end

  test "long Location names wrap into taller nodes without clipping the diagram" do
    location = @universe.locations.create!(name: "An extraordinarily long region name with many words")
    layout = LocationMapLayout.new(locations: [ location ], routes: [])
    node = layout.nodes.fetch(0)

    assert_operator node.label_lines.length, :>, 1
    assert_operator node.height, :>, LocationMapLayout::MIN_CARD_HEIGHT
    assert_operator node.bottom, :<, layout.height
    assert node.label_lines.all? { |line| line.length <= LocationMapLayout::MAX_LABEL_CHARACTERS }
  end

  test "reversing query order does not change derived coordinates or edges" do
    parent = @universe.locations.create!(name: "Central")
    child = @universe.locations.create!(name: "Harbor", parent: parent)
    destination = @universe.locations.create!(name: "Hilltop")
    route = @universe.routes.create!(from_location: child, to_location: destination)
    locations = [ parent, child, destination ]

    first = LocationMapLayout.new(locations: locations, routes: [ route ])
    second = LocationMapLayout.new(locations: locations.reverse, routes: [ route ].reverse)

    assert_equal first.nodes.map { |node| [ node.location.id, node.x, node.y ] },
      second.nodes.map { |node| [ node.location.id, node.x, node.y ] }
    assert_equal first.route_edges.map(&:path), second.route_edges.map(&:path)
    assert_equal first.hierarchy_edges.map(&:path), second.hierarchy_edges.map(&:path)
  end
end
