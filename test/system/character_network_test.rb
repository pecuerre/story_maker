require "application_system_test_case"

# The three Network view checkboxes are a client-side visibility change: the
# server lays the whole graph out once, and turning a layer off must hide
# elements without moving any node. A request test can prove the hidden classes
# are rendered; only the browser proves the checkbox changes them in place.
class CharacterNetworkTest < ApplicationSystemTestCase
  test "toggling a layer hides elements without moving the nodes" do
    universe = universes(:universe_one)
    loner = universe.characters.create!(name: "Browser Loner")
    factions(:faction_one).characters << [ characters(:character_two), loner ]

    visit universe_character_network_path(universe_slug: universe.slug)

    assert_selector ".character-network-node", count: 4
    assert_selector ".character-network-faction-link", count: 2
    assert_selector ".character-network-relation-link", count: 1
    assert_checked_field "Show characters with no connections"

    loner_node = find("a[aria-label='Open Browser Loner']")
    start_x = loner_node.find("circle")["cx"]
    start_y = loner_node.find("circle")["cy"]

    uncheck "Show characters with no connections"

    assert_current_path universe_character_network_path(
      universe_slug: universe.slug, show_unconnected: "0"
    )
    assert_selector "a[aria-label='Open Browser Loner'].character-network-hidden",
      visible: :all
    assert_selector ".character-network-faction-link.character-network-hidden",
      count: 2, visible: :all
    assert_selector ".character-network-faction-link:not(.character-network-hidden)", count: 0
    assert_selector ".character-network-relation-link.character-network-hidden", count: 0

    hidden_node = find("a[aria-label='Open Browser Loner']", visible: :all)
    assert_equal start_x, hidden_node.find("circle", visible: :all)["cx"]
    assert_equal start_y, hidden_node.find("circle", visible: :all)["cy"]

    check "Show characters with no connections"

    assert_current_path universe_character_network_path(universe_slug: universe.slug)
    assert_no_selector "a[aria-label='Open Browser Loner'].character-network-hidden",
      visible: :all

    uncheck "Show relations between characters"

    assert_current_path universe_character_network_path(
      universe_slug: universe.slug, relation_links: "0"
    )
    assert_selector ".character-network-relation-link.character-network-hidden",
      count: 1, visible: :all

    check "Show relations between characters"

    assert_current_path universe_character_network_path(universe_slug: universe.slug)
    assert_no_selector ".character-network-relation-link.character-network-hidden",
      visible: :all

    uncheck "Show faction membership"

    assert_current_path universe_character_network_path(
      universe_slug: universe.slug, faction_links: "0"
    )
    assert_selector ".character-network-faction-link.character-network-hidden",
      count: 2, visible: :all

    check "Show faction membership"

    assert_current_path universe_character_network_path(universe_slug: universe.slug)
    assert_no_selector ".character-network-faction-link.character-network-hidden",
      visible: :all
  end
end
