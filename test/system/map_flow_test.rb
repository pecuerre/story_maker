require "application_system_test_case"

class MapFlowTest < ApplicationSystemTestCase
  test "the Map shows nested locations and directional routes with details links" do
    universe = universes(:universe_one)
    root = locations(:location_one)
    child = universe.locations.create!(name: "Nested room", parent: root)

    sign_in_via_form(users(:user_one))
    visit universe_map_path(universe_slug: universe.slug)

    assert_selector "h1", text: "Map"
    within "nav[aria-label='Universe and story navigation']" do
      assert_selector "a.active[aria-current='page']", text: "Map"
    end
    assert_selector ".map-location-tree > li a[aria-label='Details for #{root.name}']", text: root.name
    assert_selector ".map-location-children > li a[aria-label='Details for #{child.name}']", text: child.name
    assert_selector ".map-diagram-node[href='#{universe_location_path(universe_slug: universe.slug, id: child)}']"
    assert_selector ".map-hierarchy-edge[data-parent-id='#{root.id}'][data-child-id='#{child.id}']"
    within ".map-route-row" do
      assert_link "#{root.name}"
      assert_selector ".visually-hidden", text: "to"
      assert_link locations(:location_two).name
      assert_link "Details", href: universe_route_path(universe_slug: universe.slug, id: routes(:route_one))
    end

    assert_selector ".map-route-row a.details-link[aria-label='Details for Road one']"
  end

  test "the diagram remains keyboard-sized, theme-aware, and scrollable on a narrow screen" do
    universe = universes(:universe_one)
    parent = locations(:location_one)
    3.times do |index|
      parent = universe.locations.create!(name: "Nested level #{index + 1}", parent: parent)
    end

    sign_in_via_form(users(:user_one))
    visit universe_map_path(universe_slug: universe.slug)
    light_fill = map_node_fill
    node = first(".map-diagram-node")
    assert_equal 0, node.evaluate_script("this.tabIndex")
    assert_operator node.evaluate_script("this.getBoundingClientRect().height"), :>=, 40
    page.execute_script("arguments[0].focus()", find(".map-diagram-scroll").native)
    page.driver.browser.action.send_keys(:tab).perform
    assert_equal "map-diagram-location-#{locations(:location_one).id}",
      page.evaluate_script("document.activeElement.id")

    visit settings_path
    choose "Dark"
    click_button "Save theme"
    assert_equal "dark", page.evaluate_script("document.documentElement.getAttribute('data-bs-theme')")
    visit universe_map_path(universe_slug: universe.slug)

    assert_equal "dark", page.evaluate_script("document.documentElement.getAttribute('data-bs-theme')")
    refute_equal light_fill, map_node_fill

    page.current_window.resize_to(390, 844)
    dimensions = page.evaluate_script("(() => { const node = document.querySelector('.map-diagram-scroll'); return [node.scrollWidth, node.clientWidth] })()")
    assert_operator dimensions.first, :>, dimensions.last
    assert_selector ".map-diagram-scroll[role=region][tabindex='0']"
  end

  private

  def map_node_fill
    page.evaluate_script("getComputedStyle(document.querySelector('.map-diagram-node rect')).fill")
  end
end
