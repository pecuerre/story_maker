require "test_helper"

class CharacterNetworksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  test "show draws the derived network and the ranked table" do
    get universe_character_network_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".page-header h1", text: "Network"
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]",
      universe_character_network_path(universe_slug: @universe.slug), text: "Network"
    assert_select "nav.content-tabs a[href=?]",
      universe_relations_path(universe_slug: @universe.slug), text: "Relations"

    assert_select "[data-controller=character-network]"
    assert_select "a[data-action='character-network#toggleFactionLinks'][data-character-network-target=factionButton]"
    assert_select "svg.character-network-svg[role=group]"
    assert_select ".character-network-node", count: 3
    assert_select ".character-network-edge", count: 3
    assert_select ".character-network-table tbody tr", count: 3
    assert_select ".character-network-table caption", text: /shared scene/i
    assert_select "main form", count: 0
  end

  test "the table reports the three counts behind an interaction score" do
    get universe_character_network_url(universe_slug: @universe.slug)

    assert_response :success
    row = css_select(".character-network-table tbody tr").find do |candidate|
      candidate.text.include?("Character one") && candidate.text.include?("Character three")
    end

    assert row, "expected the strongest pair in the table"
    assert_equal [ "1", "1", "1", "4" ], row.css("td.text-end").map { |cell| cell.text.strip }
  end

  test "a tagged Relation colors its line and repeats the tag in the table" do
    get universe_character_network_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "th", text: "Relation tag"

    tagged_edges = css_select(".character-network-edge--tagged")
    assert_equal 1, tagged_edges.size
    assert_equal "#d3d3d3", tagged_edges.first["style"][/stroke:\s*(#[0-9a-fA-F]{6})/, 1]
    assert_select ".character-network-table .taxonomy-tag", text: "Relation tag one"
    assert_select ".character-network-table td .visually-hidden", text: "No relation tag", count: 2
  end

  test "faction membership draws colored dotted links and can be turned off" do
    factions(:faction_one).update!(bgcolor: "#123456", fgcolor: "#ffffff")
    factions(:faction_one).characters << characters(:character_two)

    get universe_character_network_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".character-network-faction-link[style*=?]", "stroke: #123456", count: 1
    assert_select ".character-network-option-buttons a[role=button][aria-pressed=true]",
      text: "Show faction membership as relation"
    assert_select ".character-network-option-buttons a[href=?]",
      universe_character_network_path(universe_slug: @universe.slug, faction_links: "0"),
      text: "Show faction membership as relation"
    assert_select ".character-network-legend", text: /Dotted line: same faction/

    get universe_character_network_url(universe_slug: @universe.slug, faction_links: "0")

    assert_response :success
    assert_select ".character-network-faction-link", count: 1
    assert_select ".character-network-faction-link.character-network-hidden", count: 1
    assert_select "[data-character-network-faction-legend].character-network-hidden", count: 1
    assert_select ".character-network-option-buttons a[role=button][aria-pressed=false]",
      text: "Show faction membership as relation"
  end

  test "each network option keeps the other one as it was" do
    factions(:faction_one).characters << characters(:character_two)
    @universe.characters.create!(name: "A Loner")

    get universe_character_network_url(universe_slug: @universe.slug)

    assert_select ".character-network-option-buttons a[href=?]",
      universe_character_network_path(universe_slug: @universe.slug, show_unconnected: "0"),
      text: "Hide characters with no connections"
    assert_select ".character-network-option-buttons a[role=button][href=?]",
      universe_character_network_path(universe_slug: @universe.slug, faction_links: "0")

    get universe_character_network_url(universe_slug: @universe.slug, faction_links: "0")

    assert_select ".character-network-option-buttons a[href=?]",
      universe_character_network_path(universe_slug: @universe.slug,
        show_unconnected: "0", faction_links: "0"),
      text: "Hide characters with no connections"
    assert_select ".character-network-option-buttons a[role=button][href=?]",
      universe_character_network_path(universe_slug: @universe.slug)

    get universe_character_network_url(universe_slug: @universe.slug,
      show_unconnected: "0", faction_links: "0")

    assert_select ".character-network-option-buttons a[href=?]",
      universe_character_network_path(universe_slug: @universe.slug, faction_links: "0"),
      text: "Show 1 character with no connection"
    assert_select ".character-network-option-buttons a[role=button][href=?]",
      universe_character_network_path(universe_slug: @universe.slug, show_unconnected: "0")
  end

  test "all Characters are in the graph by default and zero only hides the unconnected ones" do
    @universe.characters.create!(name: "A Loner")

    get universe_character_network_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".character-network-options", text: /3 of 4 characters have a recorded connection/
    assert_select ".character-network-node", count: 4
    assert_select ".character-network-node.character-network-hidden", count: 0
    assert_select ".character-network-node--isolated", count: 1
    assert_select "a[data-action='character-network#toggleUnconnected'][data-character-network-target=unconnectedButton]"
    assert_select ".character-network-options a[href=?]",
      universe_character_network_path(universe_slug: @universe.slug, show_unconnected: "0"),
      text: "Hide characters with no connections"
    assert_select ".character-network-legend", text: /Dashed ring/

    get universe_character_network_url(universe_slug: @universe.slug, show_unconnected: "0")

    assert_response :success
    assert_select ".character-network-node", count: 4
    assert_select ".character-network-node:not(.character-network-hidden)", count: 3
    assert_select ".character-network-node.character-network-hidden", count: 1
    assert_select ".character-network-options a[href=?]",
      universe_character_network_path(universe_slug: @universe.slug),
      text: "Show 1 character with no connection"
  end

  test "only zero turns the unconnected layer off" do
    @universe.characters.create!(name: "A Loner")

    get universe_character_network_url(universe_slug: @universe.slug, show_unconnected: "1")

    assert_response :success
    assert_select ".character-network-node", count: 4
    assert_select ".character-network-node.character-network-hidden", count: 0

    get universe_character_network_url(universe_slug: @universe.slug, show_unconnected: "0")

    assert_response :success
    assert_select ".character-network-node", count: 4
    assert_select ".character-network-node.character-network-hidden", count: 1
  end

  test "the initial URL hides layers without removing them from the layout" do
    loner = @universe.characters.create!(name: "A Loner")
    factions(:faction_one).characters << [ characters(:character_two), loner ]

    get universe_character_network_url(universe_slug: @universe.slug, show_unconnected: "0")

    assert_response :success
    assert_select "[data-character-network-show-unconnected-value=false]"
    assert_select "[data-character-network-show-faction-links-value=true]"
    assert_select ".character-network-node", count: 4
    assert_select ".character-network-node.character-network-hidden", count: 1
    assert_select ".character-network-faction-link.character-network-hidden", count: 2
    assert_select ".character-network-faction-link:not(.character-network-hidden)", count: 1
    assert_select "[data-character-network-unconnected-legend].character-network-hidden", count: 1
    assert_select "[data-character-network-faction-legend].character-network-hidden", count: 0

    get universe_character_network_url(universe_slug: @universe.slug, faction_links: "0")

    assert_response :success
    assert_select "[data-character-network-show-faction-links-value=false]"
    assert_select ".character-network-node.character-network-hidden", count: 0
    assert_select ".character-network-faction-link", count: 3
    assert_select ".character-network-faction-link.character-network-hidden", count: 3
    assert_select "[data-character-network-faction-legend].character-network-hidden", count: 1
  end

  test "faction links can carry the graph when there is no interaction edge" do
    factions(:faction_one).characters << characters(:character_two)
    scenes(:scene_one).soft_delete

    get universe_character_network_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".character-network-svg"
    assert_select ".character-network-faction-link", count: 1
    assert_select ".character-network-table", count: 0
    assert_select "p", text: /No interaction connections recorded yet/
  end

  test "a guest can read the network of a public universe" do
    sign_out

    get universe_character_network_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".character-network-node", count: 3
  end

  test "private network access follows read, write, and admin memberships" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private Network", slug: "private-network", private: true)
    sign_out

    get universe_character_network_url(universe_slug: private_universe.slug)
    assert_response :not_found

    sign_in_as(users(:user_two))
    get universe_character_network_url(universe_slug: private_universe.slug)
    assert_response :not_found
    sign_out

    %i[ read write admin ].each do |access_level|
      membership = UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: access_level)
      sign_in_as(users(:user_two))

      get universe_character_network_url(universe_slug: private_universe.slug)
      assert_response :success, "#{access_level} members can read the network"

      sign_out
      membership.destroy!
    end

    sign_in_as(users(:user_one))
    get universe_character_network_url(universe_slug: private_universe.slug)
    assert_response :success
  end

  test "a universe with scenes but no shared interaction still shows the cast" do
    scenes(:scene_one).soft_delete

    get universe_character_network_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".character-network-svg"
    assert_select ".character-network-node", count: 3
    assert_select ".character-network-table", count: 0
    assert_select "p", text: /No interaction connections recorded yet/
  end

  test "a universe with no scenes still shows the cast" do
    Scene.where(story_id: @universe.stories.select(:id)).find_each(&:soft_delete)

    get universe_character_network_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".character-network-svg"
    assert_select ".character-network-node", count: 3
    assert_select "p", text: /No interaction connections recorded yet/
  end

  test "a universe with no characters says so" do
    @universe.characters.find_each(&:soft_delete)

    get universe_character_network_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".empty-title", text: "No characters yet"
    assert_select ".character-network-options", count: 0
    assert_select ".character-network-svg", count: 0
  end
end
