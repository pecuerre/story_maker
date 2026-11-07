require "application_system_test_case"

# The two Network view toggles are a client-side visibility change: the server
# lays the whole graph out once, and turning a layer off must hide elements
# without moving any node. A request test can prove the hidden classes are
# rendered; only the browser proves the click changes them in place.
class CharacterNetworkTest < ApplicationSystemTestCase
  test "toggling a layer hides elements without moving the nodes" do
    universe = universes(:universe_one)
    loner = universe.characters.create!(name: "Browser Loner")
    factions(:faction_one).characters << [ characters(:character_two), loner ]

    visit universe_character_network_path(universe_slug: universe.slug)

    assert_selector ".character-network-node", count: 4
    assert_selector ".character-network-faction-link", count: 3
    assert_link "Hide characters with no connections"

    loner_node = find("a[aria-label='Open Browser Loner']")
    start_x = loner_node.find("circle")["cx"]
    start_y = loner_node.find("circle")["cy"]

    click_link "Hide characters with no connections"

    assert_current_path universe_character_network_path(
      universe_slug: universe.slug, show_unconnected: "0"
    )
    assert_selector "a[aria-label='Open Browser Loner'].character-network-hidden",
      visible: :all
    assert_selector ".character-network-faction-link.character-network-hidden",
      count: 2, visible: :all
    assert_selector ".character-network-faction-link:not(.character-network-hidden)", count: 1
    assert_link "Show 1 character with no connection"

    hidden_node = find("a[aria-label='Open Browser Loner']", visible: :all)
    assert_equal start_x, hidden_node.find("circle", visible: :all)["cx"]
    assert_equal start_y, hidden_node.find("circle", visible: :all)["cy"]

    click_link "Show 1 character with no connection"

    assert_current_path universe_character_network_path(universe_slug: universe.slug)
    assert_no_selector "a[aria-label='Open Browser Loner'].character-network-hidden",
      visible: :all

    click_link "Show faction membership as relation"

    assert_current_path universe_character_network_path(
      universe_slug: universe.slug, faction_links: "0"
    )
    assert_selector ".character-network-faction-link.character-network-hidden",
      count: 3, visible: :all
    assert_link "Show faction membership as relation"

    click_link "Show faction membership as relation"

    assert_current_path universe_character_network_path(universe_slug: universe.slug)
    assert_no_selector ".character-network-faction-link.character-network-hidden",
      visible: :all
  end
end
