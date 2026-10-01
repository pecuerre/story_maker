require "test_helper"

# An unknown optional reference id must answer the documented JSON error hash,
# not a 500.
#
# The foreign keys are real, so before `parent_reference_exists` and
# `temporal_references_exist` these submissions were refused by SQLite and
# surfaced as an unhandled exception: the editor reported that the server failed
# without saying which field was wrong, and nothing in the error summary pointed
# at the control. Each case below is a real mutation through the real endpoint,
# asserted on the status, on the field that carried the bad id, and on the fact
# that no row was written.
#
# Every JSON-only controller that accepts `parent_id` is covered, because the rule
# lives in the shared concern rather than in a controller: an endpoint left out of
# this list would be one whose author had to remember the rule.
class UnknownReferenceIdsTest < ActionDispatch::IntegrationTest
  MISSING_ID = 999_999

  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  # The endpoint, the model it writes, and the payload each one requires. A tag
  # whose own validations would fail first would answer 422 for the wrong reason,
  # so every payload carries the attributes its controller needs. Route keys are
  # spelled out rather than gathered, because `UniverseRouteHelperArgumentsTest`
  # requires the universe and story scope to be explicit at every call site.
  def parent_mutations
    {
      "characters" => [ universe_characters_path(universe_slug: @universe.slug), Character,
        { character: { name: "Dangling", parent_id: MISSING_ID } } ],
      "locations" => [ universe_locations_path(universe_slug: @universe.slug), Location,
        { location: { name: "Dangling", parent_id: MISSING_ID } } ],
      "items" => [ universe_items_path(universe_slug: @universe.slug), Item,
        { item: { name: "Dangling", parent_id: MISSING_ID } } ],
      "events" => [ universe_events_path(universe_slug: @universe.slug), Event,
        { event: { title: "Dangling", parent_id: MISSING_ID } } ],
      "character tags" => [ universe_character_tags_path(universe_slug: @universe.slug), CharacterTag,
        { character_tag: { name: "Dangling", parent_id: MISSING_ID } } ],
      "location tags" => [ universe_location_tags_path(universe_slug: @universe.slug), LocationTag,
        { location_tag: { name: "Dangling", parent_id: MISSING_ID } } ],
      "item tags" => [ universe_item_tags_path(universe_slug: @universe.slug), ItemTag,
        { item_tag: { name: "Dangling", parent_id: MISSING_ID } } ],
      "event tags" => [ universe_event_tags_path(universe_slug: @universe.slug), EventTag,
        { event_tag: { name: "Dangling", parent_id: MISSING_ID } } ],
      "relation tags" => [ universe_relation_tags_path(universe_slug: @universe.slug), RelationTag,
        { relation_tag: { name: "Dangling", parent_id: MISSING_ID, symmetric: false } } ],
      "ownership tags" => [ universe_ownership_tags_path(universe_slug: @universe.slug), OwnershipTag,
        { ownership_tag: { name: "Dangling", parent_id: MISSING_ID } } ],
      # The three story-scoped trees, whose hierarchy scope is the story rather
      # than the universe.
      "sections" => [ universe_story_sections_path(universe_slug: @universe.slug, story_id: @story.id), Section,
        { section: { name: "Dangling", parent_id: MISSING_ID } } ],
      "section tags" => [ universe_story_section_tags_path(universe_slug: @universe.slug, story_id: @story.id), SectionTag,
        { section_tag: { name: "Dangling", parent_id: MISSING_ID } } ],
      "scene tags" => [ universe_story_scene_tags_path(universe_slug: @universe.slug, story_id: @story.id), SceneTag,
        { scene_tag: { name: "Dangling", parent_id: MISSING_ID } } ]
    }
  end

  test "an unknown parent is a 422 field error on every workspace that accepts a parent" do
    parent_mutations.each do |name, (path, model, params)|
      assert_no_difference -> { model.count } do
        post path, params: params, as: :json
      end

      assert_response :unprocessable_content, "#{name} did not answer the documented error status"
      assert_equal [ I18n.t("shared.errors.hierarchy.must_exist") ], response.parsed_body["parent"],
        "#{name} did not report the unknown parent on the field that carried it"
    end
  end

  test "an unknown parent on an update is a 422 field error and keeps the stored record" do
    character = characters(:character_one)

    patch universe_character_path(universe_slug: @universe.slug, id: character.id),
      params: { character: { name: character.name, parent_id: MISSING_ID } }, as: :json

    assert_response :unprocessable_content
    assert_equal [ I18n.t("shared.errors.hierarchy.must_exist") ], response.parsed_body["parent"]
    assert_nil character.reload.parent_id
  end

  test "an unknown temporal reference is a 422 field error" do
    %i[before_event_id after_event_id simultaneous_event_id].each do |field|
      assert_no_difference -> { Event.count } do
        post universe_events_path(universe_slug: @universe.slug),
          params: { event: { title: "Dangling reference", field => MISSING_ID } }, as: :json
      end

      assert_response :unprocessable_content, "#{field} did not answer the documented error status"
      assert_equal [ I18n.t("events.errors.must_exist") ], response.parsed_body[field.to_s.delete_suffix("_id")],
        "the unknown #{field} was not reported on the field that carried it"
    end
  end

  test "a valid parent still saves through the same endpoint" do
    # The counterpart of the rule above: a rejection test that never shows the
    # accepted path is satisfied by a controller that refuses everything.
    parent = characters(:character_one)

    post universe_characters_path(universe_slug: @universe.slug),
      params: { character: { name: "Nested", parent_id: parent.id } }, as: :json

    assert_response :success
    assert_equal parent.id, Character.find_by!(name: "Nested").parent_id
  end
end
