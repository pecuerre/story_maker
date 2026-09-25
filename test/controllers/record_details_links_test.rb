require "test_helper"

# The Details link is the new way into every record's own page. It must render
# on every list row and taxonomy node, for read-only viewers too, and its count
# must match what the destination lists.
class RecordDetailsLinksTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  test "a taxonomy row links to its own page with the number of records carrying it" do
    tag = character_tags(:character_tag_one)

    get universe_character_tags_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "li[data-node-id=?] a.details-link[href=?]",
      tag.id.to_s, universe_character_tag_path(universe_slug: @universe.slug, id: tag),
      text: "Details (1 character)"
  end

  test "the shared taxonomy workspace renders the same count" do
    tag = item_tags(:item_tag_one)

    get universe_tags_url(universe_slug: @universe.slug, scope: "universe", taxonomy: "item")

    assert_response :success
    assert_select "li[data-node-id=?] a.details-link[href=?] .details-link-count",
      tag.id.to_s, universe_item_tag_path(universe_slug: @universe.slug, id: tag),
      text: "(1 item)"
  end

  test "a section row counts the scenes grouped under it and a location row links without a count" do
    section = sections(:section_one)
    location = locations(:location_one)

    get universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)
    assert_response :success
    assert_select "li[data-node-id=?] a.details-link[href=?] .details-link-count",
      section.id.to_s, universe_story_section_path(universe_slug: @universe.slug, story_id: @story, id: section),
      text: "(1 scene)"

    get universe_locations_url(universe_slug: @universe.slug)
    assert_response :success
    assert_select "li[data-node-id=?] a.details-link[href=?]", location.id.to_s,
      universe_location_path(universe_slug: @universe.slug, id: location),
      text: "Details"
  end

  test "flat list rows link to their own page" do
    {
      characters: [ characters(:character_one), :universe_character_path ],
      items: [ items(:item_one), :universe_item_path ],
      events: [ events(:event_one), :universe_event_path ]
    }.each do |route, (record, path_helper)|
      get send("universe_#{route}_url", universe_slug: @universe.slug)

      assert_response :success
      assert_select "a.details-link[href=?]", send(path_helper, universe_slug: @universe.slug, id: record)
    end
  end

  test "the link is present for a guest on a public universe" do
    sign_out
    tag = character_tags(:character_tag_one)

    get universe_character_tags_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "li[data-node-id=?] a.details-link[href=?]", tag.id.to_s,
      universe_character_tag_path(universe_slug: @universe.slug, id: tag)
  end
end
