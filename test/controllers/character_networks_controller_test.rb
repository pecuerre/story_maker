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
    assert_select "form[method=get] input[type=checkbox][name=show_unconnected][checked]"
    assert_select "form[method=get] input[type=checkbox][name=relation_links][checked]"
    assert_select "form[method=get] input[type=checkbox][name=faction_links][checked]"
    assert_select "svg.character-network-svg[role=group]"
    assert_select ".character-network-node", count: 3
    assert_select ".character-network-edge", count: 3
    assert_select ".character-network-relation-link", count: 1
    assert_select ".character-network-table tbody tr", count: 3
    assert_select ".character-network-table caption", text: /shared scene/i
    assert_select "main form", { count: 1 }, "the view options are the page's only form"
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

  test "a tagged Relation draws a dashed link in its tag color and repeats the tag in the table" do
    get universe_character_network_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "th", text: "Relation tag"

    relation_links = css_select(".character-network-relation-link")
    assert_equal 1, relation_links.size
    assert_equal "#d3d3d3", relation_links.first["style"][/stroke:\s*(#[0-9a-fA-F]{6})/, 1]
    assert_select ".character-network-edge[style]", { count: 0 },
      "the solid interaction line is always neutral"
    assert_select ".character-network-table .taxonomy-tag", text: "Relation tag one"
    assert_select ".character-network-table td .visually-hidden", text: "No relation tag", count: 2

    get universe_character_network_url(universe_slug: @universe.slug, relation_links: "0")

    assert_response :success
    assert_select "input[type=checkbox][name=relation_links]:not([checked])"
    assert_select ".character-network-relation-link.character-network-hidden", count: 1
    assert_select "[data-character-network-relation-legend].character-network-hidden", count: 1
  end

  test "faction membership draws neutral dotted links and can be turned off" do
    first = @universe.characters.create!(name: "Faction first")
    second = @universe.characters.create!(name: "Faction second")
    factions(:faction_two).update!(bgcolor: "#123456", fgcolor: "#ffffff")
    factions(:faction_two).characters << [ first, second ]

    get universe_character_network_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".character-network-faction-link", count: 1
    assert_select ".character-network-faction-link[style]", { count: 0 },
      "the dotted faction line is always neutral"
    assert_select "label[for=character_network_faction_links]",
      text: "Show faction membership"
    assert_select "input[type=checkbox][name=faction_links][checked]"
    assert_select ".character-network-legend", text: /Dotted line: same faction/

    get universe_character_network_url(universe_slug: @universe.slug, faction_links: "0")

    assert_response :success
    assert_select ".character-network-faction-link", count: 1
    assert_select ".character-network-faction-link.character-network-hidden", count: 1
    assert_select "[data-character-network-faction-legend].character-network-hidden", count: 1
    assert_select "input[type=checkbox][name=faction_links]:not([checked])"
  end

  test "each checkbox reflects its own URL option" do
    @universe.characters.create!(name: "A Loner")

    get universe_character_network_url(universe_slug: @universe.slug)

    assert_select "input[type=checkbox][checked]", count: 3

    get universe_character_network_url(universe_slug: @universe.slug, show_unconnected: "0")

    assert_select "input[type=checkbox][name=show_unconnected]:not([checked])"
    assert_select "input[type=checkbox][name=relation_links][checked]"
    assert_select "input[type=checkbox][name=faction_links][checked]"

    get universe_character_network_url(universe_slug: @universe.slug, relation_links: "0")

    assert_select "input[type=checkbox][name=show_unconnected][checked]"
    assert_select "input[type=checkbox][name=relation_links]:not([checked])"
    assert_select "input[type=checkbox][name=faction_links][checked]"

    get universe_character_network_url(universe_slug: @universe.slug, faction_links: "0")

    assert_select "input[type=checkbox][name=show_unconnected][checked]"
    assert_select "input[type=checkbox][name=relation_links][checked]"
    assert_select "input[type=checkbox][name=faction_links]:not([checked])"
  end

  test "all Characters are in the graph by default and zero only hides the unconnected ones" do
    @universe.characters.create!(name: "A Loner")

    get universe_character_network_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".character-network-options", text: /3 of 4 characters have a recorded connection/
    assert_select ".character-network-node", count: 4
    assert_select ".character-network-node.character-network-hidden", count: 0
    assert_select ".character-network-node--isolated", count: 1
    assert_select "input[type=checkbox][name=show_unconnected][checked]"
    assert_select ".character-network-legend", text: /Dashed ring/

    get universe_character_network_url(universe_slug: @universe.slug, show_unconnected: "0")

    assert_response :success
    assert_select ".character-network-node", count: 4
    assert_select ".character-network-node:not(.character-network-hidden)", count: 3
    assert_select ".character-network-node.character-network-hidden", count: 1
    assert_select "input[type=checkbox][name=show_unconnected]:not([checked])"
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
    assert_select "[data-character-network-show-relation-links-value=true]"
    assert_select "[data-character-network-show-faction-links-value=true]"
    assert_select ".character-network-node", count: 4
    assert_select ".character-network-node.character-network-hidden", count: 1
    assert_select ".character-network-faction-link", count: 2
    assert_select ".character-network-faction-link.character-network-hidden", count: 2
    assert_select ".character-network-relation-link.character-network-hidden", count: 0
    assert_select "[data-character-network-unconnected-legend].character-network-hidden", count: 1
    assert_select "[data-character-network-relation-legend].character-network-hidden", count: 0
    assert_select "[data-character-network-faction-legend].character-network-hidden", count: 0

    get universe_character_network_url(universe_slug: @universe.slug, faction_links: "0")

    assert_response :success
    assert_select "[data-character-network-show-faction-links-value=false]"
    assert_select ".character-network-node.character-network-hidden", count: 0
    assert_select ".character-network-faction-link", count: 2
    assert_select ".character-network-faction-link.character-network-hidden", count: 2
    assert_select "[data-character-network-faction-legend].character-network-hidden", count: 1
  end

  test "faction links can carry the graph when there is no interaction or Relation" do
    first = @universe.characters.create!(name: "Faction first")
    second = @universe.characters.create!(name: "Faction second")
    factions(:faction_two).characters << [ first, second ]
    scenes(:scene_one).soft_delete
    relations(:relation_one).soft_delete

    get universe_character_network_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".character-network-svg"
    assert_select ".character-network-faction-link", count: 1
    assert_select ".character-network-relation-link", count: 0
    assert_select ".character-network-table", count: 0
    assert_select "p", text: /No interaction connections recorded yet/
  end

  test "relation links can carry the graph when there is no interaction or faction" do
    first = @universe.characters.create!(name: "Relation first")
    second = @universe.characters.create!(name: "Relation second")
    @universe.relations.create!(character1: first, character2: second)
    scenes(:scene_one).soft_delete
    relations(:relation_one).soft_delete

    get universe_character_network_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".character-network-svg"
    assert_select ".character-network-relation-link", count: 1
    assert_select ".character-network-faction-link", count: 0
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
