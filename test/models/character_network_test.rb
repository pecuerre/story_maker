require "test_helper"

# The network is a derivation, so its tests build Scenes and Dialogue through
# the same models the application uses and read the result back. The union of
# explicit presence and Dialogue speakers is `SceneParticipants`' contract and is
# covered there; these tests hold the network to the signals it adds on top of
# that union.
class CharacterNetworkTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @network = CharacterNetwork.new(@universe)
  end

  test "scores a pair from shared scenes, shared dialogue, and exchanges" do
    edge = edge_between(characters(:character_one), characters(:character_three))

    assert_equal 1, edge.shared_scenes, "one Scene, not the explicit link plus the spoken line"
    assert_equal 1, edge.shared_dialogue_elements
    assert_equal 1, edge.exchanges, "the two adjacent turns are a back-and-forth"
    assert_equal 4, edge.weight
  end

  test "presence and speaking overlap on one Scene instead of summing" do
    edge = edge_between(characters(:character_one), characters(:character_two))

    assert_equal 1, edge.shared_scenes
    assert_equal 0, edge.shared_dialogue_elements
    assert_equal 0, edge.exchanges
    assert_equal 1, edge.weight
  end

  test "a dialogue with one repeated speaker has no exchange" do
    scene_dialogue_turns(:turn_two).update!(speaker: characters(:character_three))
    @network = CharacterNetwork.new(@universe)

    edge = edge_between(characters(:character_one), characters(:character_three))

    assert_equal 0, edge.exchanges
    assert_equal 0, edge.shared_dialogue_elements
    assert_equal 1, edge.weight, "only the shared Scene remains"
  end

  test "a pair takes the tag of its tagged Relation and stays neutral otherwise" do
    tagged = edge_between(characters(:character_one), characters(:character_two))
    untagged = edge_between(characters(:character_one), characters(:character_three))

    assert_equal relation_tags(:relation_tag_one), tagged.relation_tag
    assert_nil untagged.relation_tag
  end

  test "a Relation in either direction colors the same undirected pair" do
    @universe.relations.create!(
      character1: characters(:character_three),
      character2: characters(:character_two),
      relation_tags: [ relation_tags(:relation_tag_two) ]
    )
    @network = CharacterNetwork.new(@universe)

    edge = edge_between(characters(:character_two), characters(:character_three))

    assert_equal relation_tags(:relation_tag_two), edge.relation_tag
  end

  test "the first tagged Relation in id order supplies the color" do
    later = @universe.relations.create!(
      character1: characters(:character_one),
      character2: characters(:character_two),
      relation_tags: [ relation_tags(:relation_tag_two) ]
    )
    @network = CharacterNetwork.new(@universe)

    edge = edge_between(characters(:character_one), characters(:character_two))

    assert_operator relations(:relation_one).id, :<, later.id
    assert_equal relation_tags(:relation_tag_one), edge.relation_tag
  end

  test "a soft-deleted Relation no longer colors an interaction edge" do
    relations(:relation_one).soft_delete
    @network = CharacterNetwork.new(@universe)

    assert_nil edge_between(characters(:character_one), characters(:character_two)).relation_tag
  end

  test "prose mentions and Relations are not interaction evidence" do
    scenes(:scene_two).scene_elements.create!(
      name: "Named in passing", kind: SceneElement::NARRATION,
      body: "Character one and Character two are only spoken of here.", position: 0
    )

    network = CharacterNetwork.new(@universe)
    edge = network.edges.find do |candidate|
      endpoint_ids(candidate) == [ characters(:character_one).id, characters(:character_two).id ].sort
    end

    assert_equal 1, edge.weight, "the mention and the existing Relation add nothing"
  end

  test "soft-deleted Scenes and their links disappear from the derivation" do
    scenes(:scene_one).soft_delete

    assert_empty CharacterNetwork.new(@universe).edges
  end

  test "only live Characters of the Universe become nodes" do
    @network.nodes.each do |node|
      assert_equal @universe.id, node.character.universe_id
      assert_nil node.character.deleted_at
    end

    other = CharacterNetwork.new(universes(:universe_two))
    assert_empty other.nodes
    assert_empty other.edges
  end

  test "same-faction pairs are a separate layer that is on by default" do
    factions(:faction_one).characters << characters(:character_two)

    network = CharacterNetwork.new(@universe)
    link = network.faction_links.find do |candidate|
      endpoint_ids(candidate) == [ characters(:character_one).id, characters(:character_two).id ].sort
    end

    assert link, "the two faction members get a faction link"
    assert_equal [ factions(:faction_one) ], link.factions
    assert_equal 3, network.edges.size, "faction membership does not change the interaction layer"
    assert_empty CharacterNetwork.new(@universe, include_faction_links: false).faction_links
  end

  test "a pair in several factions gets one link carrying all of them" do
    factions(:faction_one).characters << characters(:character_two)
    factions(:faction_two).characters << [ characters(:character_one), characters(:character_two) ]

    link = CharacterNetwork.new(@universe).faction_links.find do |candidate|
      endpoint_ids(candidate) == [ characters(:character_one).id, characters(:character_two).id ].sort
    end

    assert_equal [ factions(:faction_one), factions(:faction_two) ], link.factions
  end

  test "a faction member without interaction joins the graph only when unconnected is on" do
    loner = @universe.characters.create!(name: "Faction only")
    factions(:faction_one).characters << [ characters(:character_two), loner ]

    connected_only = CharacterNetwork.new(@universe)
    assert_equal 1, connected_only.faction_links.size
    assert_not_includes connected_only.nodes.map(&:character), loner

    whole_cast = CharacterNetwork.new(@universe, include_unconnected: true)
    assert_equal 3, whole_cast.faction_links.size
    assert_includes whole_cast.nodes.map(&:character), loner
  end

  test "a soft-deleted Faction contributes no links" do
    factions(:faction_one).characters << characters(:character_two)
    factions(:faction_one).soft_delete

    assert_empty CharacterNetwork.new(@universe).faction_links
  end

  test "faction links are bounded and say when they truncated" do
    faction = @universe.factions.create!(name: "A very large faction")
    19.times do |index|
      faction.characters << @universe.characters.create!(name: format("Member %02d", index))
    end

    network = CharacterNetwork.new(@universe, include_unconnected: true)

    assert_equal CharacterNetwork::MAX_FACTION_LINKS, network.faction_links.size
    assert network.faction_links_truncated?
  end

  test "a Character with no pair is reported and only drawn when asked for" do
    loner = @universe.characters.create!(name: "A Loner")

    connected_only = CharacterNetwork.new(@universe)

    assert_equal 3, connected_only.connected_count
    assert_equal 4, connected_only.character_total
    assert_includes connected_only.unconnected_characters, loner
    assert_not_includes connected_only.nodes.map(&:character), loner

    whole_cast = CharacterNetwork.new(@universe, include_unconnected: true)
    node = whole_cast.nodes.find { |candidate| candidate.character == loner }

    assert node, "the requested whole cast includes the isolated Character"
    assert_equal 0, node.interaction_total
    assert_equal 0, node.degree
    assert_equal 4, whole_cast.nodes.size
    refute whole_cast.nodes_truncated?
  end

  test "the diagram and table keep the strongest pairs and say when they truncate" do
    scene = scenes(:scene_three)
    30.times do |index|
      character = @universe.characters.create!(name: format("Cap %02d", index))
      scene.scene_characters.create!(character: character)
    end

    network = CharacterNetwork.new(@universe)

    assert_equal (30 * 29 / 2) + 3, network.total_edge_count
    assert_equal CharacterNetwork::MAX_EDGES, network.edges.size
    assert network.truncated?
    assert network.edges.each_cons(2).all? { |left, right| left.weight >= right.weight }
  end

  private

    def edge_between(first, second)
      expected = [ first.id, second.id ].sort
      edge = @network.edges.find { |candidate| endpoint_ids(candidate) == expected }

      assert edge, "expected a connection between #{first.name} and #{second.name}"
      edge
    end

    def endpoint_ids(edge)
      [ edge.character_a.id, edge.character_b.id ].sort
    end
end
