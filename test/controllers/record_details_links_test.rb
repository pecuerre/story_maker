require "test_helper"

# The Details link is the new way into every record's own page. It must render
# on every list row and taxonomy node, for read-only viewers too, and the count
# of related records must sit beside the name rather than inside the link.
class RecordDetailsLinksTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  test "a taxonomy row links to its own page and counts the records carrying it beside the name" do
    tag = character_tags(:character_tag_one)

    get universe_character_tags_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "li[data-node-id=?] a.details-link[href=?]", tag.id.to_s,
      universe_character_tag_path(universe_slug: @universe.slug, id: tag),
      text: "Details"
    assert_select "li[data-node-id=?] .taxonomy-name-area .record-count", tag.id.to_s,
      text: "(1 character)"
  end

  test "the shared taxonomy workspace renders the same count" do
    tag = item_tags(:item_tag_one)

    get universe_tags_url(universe_slug: @universe.slug, scope: "universe", taxonomy: "item")

    assert_response :success
    assert_select "li[data-node-id=?] .taxonomy-name-area .record-count", tag.id.to_s,
      text: "(1 item)"
  end

  test "a section row counts the scenes grouped under it and a location row links without a count" do
    section = sections(:section_one)
    location = locations(:location_one)

    get universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)
    assert_response :success
    assert_select "li[data-node-id=?] a.details-link[href=?]", section.id.to_s,
      universe_story_section_path(universe_slug: @universe.slug, story_id: @story, id: section),
      text: "Details"
    assert_select "li[data-node-id=?] .taxonomy-name-area .record-count", section.id.to_s,
      text: "(1 scene)"

    get universe_locations_url(universe_slug: @universe.slug)
    assert_response :success
    assert_select "li[data-node-id=?] a.details-link[href=?]", location.id.to_s,
      universe_location_path(universe_slug: @universe.slug, id: location),
      text: "Details"
    assert_select "li[data-node-id=?] .record-count", location.id.to_s, count: 0
  end

  test "a tag row spells out what it counts, in the plural and at zero" do
    tag = character_tags(:character_tag_one)
    tag.update!(name: "Family Nielsen")
    2.times do |index|
      character = Character.create!(universe: @universe, name: "Nielsen #{index + 1}")
      character.character_tags = [ tag ]
    end
    unused = CharacterTag.create!(universe: @universe, name: "Unused tag")

    get universe_character_tags_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "li[data-node-id=?] .record-count", tag.id.to_s, text: "(3 characters)"
    assert_select "li[data-node-id=?] .record-count", unused.id.to_s, text: "(0 characters)"
    # The count sits beside the name and never inside the link.
    assert_select "li[data-node-id=?] a.details-link", tag.id.to_s, text: "Details"
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

  test "a scene row links to the scene page and its title is plain text" do
    scene = scenes(:scene_one)

    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_select ".entity-row a.details-link[href=?]",
      universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: scene),
      text: "Details"
    assert_select ".entity-row .entity-title", text: scene.name, count: 1
    assert_select ".entity-row .entity-title a", count: 0
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
