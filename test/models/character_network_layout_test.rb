require "test_helper"

class CharacterNetworkLayoutTest < ActiveSupport::TestCase
  setup do
    @network = CharacterNetwork.new(universes(:universe_one))
  end

  test "places every node inside the padded drawing area and joins each pair once" do
    layout = CharacterNetworkLayout.new(@network)

    assert_equal @network.nodes.map(&:character), layout.nodes.map(&:character)
    assert_equal @network.edges.size, layout.edges.size
    assert_equal @network.edges.map(&:relation_tag), layout.edges.map(&:relation_tag)
    assert_equal layout.width, layout.width.to_i
    assert_operator layout.width, :>=, CharacterNetworkLayout::MIN_WIDTH

    layout.nodes.each do |node|
      assert_operator node.x, :>=, CharacterNetworkLayout::PADDING
      assert_operator node.x, :<=, layout.width - CharacterNetworkLayout::PADDING
      assert_operator node.y, :>=, CharacterNetworkLayout::PADDING
      assert_operator node.y, :<=, layout.height - CharacterNetworkLayout::PADDING
      assert_operator node.radius, :>=, CharacterNetworkLayout::MIN_RADIUS
    end
  end

  test "the same network always produces the same picture" do
    first = CharacterNetworkLayout.new(CharacterNetwork.new(universes(:universe_one)))
    second = CharacterNetworkLayout.new(CharacterNetwork.new(universes(:universe_one)))

    assert_equal coordinates(first), coordinates(second)
  end

  test "a stronger pair is drawn with a thicker line" do
    layout = CharacterNetworkLayout.new(@network)
    strongest = @network.edges.max_by(&:weight)
    weakest = @network.edges.min_by(&:weight)
    strongest_edge = layout.edges.find { |edge| edge.weight == strongest.weight }
    weakest_edge = layout.edges.find { |edge| edge.weight == weakest.weight }

    assert_operator strongest_edge.stroke_width, :>, weakest_edge.stroke_width
  end

  test "a character with more interaction is drawn larger" do
    layout = CharacterNetworkLayout.new(@network)
    busiest = layout.nodes.max_by(&:interaction_total)
    quietest = layout.nodes.min_by(&:interaction_total)

    assert_operator busiest.radius, :>, quietest.radius
  end

  test "long names are shortened in the label while the record keeps its full name" do
    long_name = "An extraordinarily long character name"
    character = universes(:universe_one).characters.create!(name: long_name)
    partner = universes(:universe_one).characters.create!(name: "Short partner")
    scene = scenes(:scene_three)
    scene.scene_characters.create!(character: character)
    scene.scene_characters.create!(character: partner)

    layout = CharacterNetworkLayout.new(CharacterNetwork.new(universes(:universe_one)))
    node = layout.nodes.find { |candidate| candidate.character == character }

    assert_equal long_name, node.character.name
    assert_operator node.label.length, :<=, CharacterNetworkLayout::MAX_LABEL_LENGTH
    assert node.label.end_with?("…")
  end

  test "an isolated Character is simulated inside the canvas at the minimum radius" do
    loner = universes(:universe_one).characters.create!(name: "A Loner")
    network = CharacterNetwork.new(universes(:universe_one), include_unconnected: true)
    layout = CharacterNetworkLayout.new(network)
    node = layout.nodes.find { |candidate| candidate.character == loner }

    assert node
    assert_equal CharacterNetworkLayout::MIN_RADIUS, node.radius
    assert_operator node.x, :>=, CharacterNetworkLayout::PADDING
    assert_operator node.x, :<=, layout.width - CharacterNetworkLayout::PADDING
    assert_operator node.y, :>=, CharacterNetworkLayout::PADDING
    assert_operator node.y, :<=, layout.height - CharacterNetworkLayout::PADDING
  end

  test "a faction link pulls its two nodes into the simulation" do
    loner = universes(:universe_one).characters.create!(name: "A Loner")
    factions(:faction_one).characters << loner

    without_factions = CharacterNetworkLayout.new(
      CharacterNetwork.new(universes(:universe_one), include_unconnected: true, include_faction_links: false)
    )
    with_factions = CharacterNetworkLayout.new(
      CharacterNetwork.new(universes(:universe_one), include_unconnected: true)
    )
    before = without_factions.nodes.find { |candidate| candidate.character == loner }
    after = with_factions.nodes.find { |candidate| candidate.character == loner }

    refute_equal [ before.x, before.y ], [ after.x, after.y ],
      "the faction spring changes where the isolated Character settles"
  end

  test "faction links are placed on the same nodes as the interaction graph" do
    factions(:faction_one).characters << characters(:character_two)
    network = CharacterNetwork.new(universes(:universe_one), include_unconnected: true)
    layout = CharacterNetworkLayout.new(network)
    link = layout.faction_links.first

    assert_equal 1, layout.faction_links.size
    assert_includes layout.nodes, link.source
    assert_includes layout.nodes, link.target
    assert_equal [ factions(:faction_one) ], link.factions
  end

  test "a network with no positive pair still has a bounded empty canvas" do
    layout = CharacterNetworkLayout.new(CharacterNetwork.new(universes(:universe_two)))

    assert_empty layout.nodes
    assert_empty layout.edges
    assert_operator layout.width, :>=, CharacterNetworkLayout::MIN_WIDTH
    assert_operator layout.height, :>=, CharacterNetworkLayout::MIN_HEIGHT
  end

  private

    def coordinates(layout)
      layout.nodes.map { |node| [ node.character.id, node.x, node.y, node.radius ] }
    end
end
