require "test_helper"

# A list row's name is a second route to the record, beside its Details action.
# The taxonomy tree is deliberately absent: a writer's tree name is the inline
# rename trigger, so it stays plain text and the tree's Details link remains.
class RecordTitleLinksTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  test "the Universe flat lists link each row's name and keep the Details action" do
    {
      characters: [ characters(:character_one), :universe_character_path ],
      items: [ items(:item_one), :universe_item_path ],
      events: [ events(:event_one), :universe_event_path ],
      relations: [ relations(:relation_one), :universe_relation_path ],
      factions: [ factions(:faction_one), :universe_faction_path ],
      canon_rules: [ canon_rules(:canon_rule_one), :universe_canon_rule_path ],
      routes: [ routes(:route_one), :universe_route_path ],
      faction_relationships: [
        faction_relationships(:faction_relationship_one), :universe_faction_relationship_path
      ]
    }.each do |route, (record, path_helper)|
      get send("universe_#{route}_url", universe_slug: @universe.slug)
      assert_response :success

      path = send(path_helper, universe_slug: @universe.slug, id: record)
      assert_select ".entity-row a.entity-title-link[href=?]", path
      assert_select ".entity-row .dropdown-menu a[href=?]", path, text: "Details"
    end
  end

  test "the Ownerships row links both endpoints and keeps the ownership's Details action" do
    ownership = ownerships(:ownership_one)

    get universe_ownerships_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".entity-row a.entity-title-link[href=?]",
      universe_item_path(universe_slug: @universe.slug, id: ownership.item)
    assert_select ".entity-row a.entity-title-link[href=?]",
      universe_character_path(universe_slug: @universe.slug, id: ownership.character)
    assert_select ".entity-row .dropdown-menu a[href=?]",
      universe_ownership_path(universe_slug: @universe.slug, id: ownership), text: "Details"
  end

  test "the Story's Scene and Plot lists link their names" do
    scene = scenes(:scene_one)
    plot = plots(:plot_one)

    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)
    assert_response :success
    assert_select ".entity-row a.entity-title-link[href=?]",
      universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: scene)

    get universe_story_plots_url(universe_slug: @universe.slug, story_id: @story)
    assert_response :success
    assert_select ".entity-row a.entity-title-link[href=?]",
      universe_story_plot_path(universe_slug: @universe.slug, story_id: @story, id: plot)
  end

  test "the three Scene workspaces link the participant records" do
    scene = scenes(:scene_one)
    base = { universe_slug: @universe.slug, story_id: @story, scene_id: scene }

    get universe_story_scene_scene_characters_url(**base)
    assert_response :success
    assert_select ".entity-row a.entity-title-link[href=?]",
      universe_character_path(universe_slug: @universe.slug, id: characters(:character_one))

    get universe_story_scene_scene_items_url(**base)
    assert_response :success
    assert_select ".entity-row a.entity-title-link[href=?]",
      universe_item_path(universe_slug: @universe.slug, id: items(:item_one))

    get universe_story_scene_scene_locations_url(**base)
    assert_response :success
    assert_select ".entity-row a.entity-title-link[href=?]",
      universe_location_path(universe_slug: @universe.slug, id: locations(:location_one))
  end

  test "the Scene Events workspace and Narrative order use the same linked-name shape" do
    scene = scenes(:scene_one)
    event = events(:event_one)

    get universe_story_scene_scene_events_url(
      universe_slug: @universe.slug, story_id: @story, scene_id: scene
    )
    assert_response :success
    assert_select ".entity-row a.entity-title-link[href=?]",
      universe_event_path(universe_slug: @universe.slug, id: event)

    get universe_story_narrative_order_url(universe_slug: @universe.slug, story_id: @story)
    assert_response :success
    assert_select "a.entity-title-link[href=?]",
      universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: scene)
  end

  test "the Map's Route row and the Universe chooser link their names" do
    get universe_map_url(universe_slug: @universe.slug)
    assert_response :success
    assert_select ".map-route-row a.entity-title-link[href=?]",
      universe_route_path(universe_slug: @universe.slug, id: routes(:route_one))

    get universes_url
    assert_response :success
    assert_select ".entity-row a.entity-title-link[href=?]", universe_path(@universe)
  end
end
