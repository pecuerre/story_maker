require "test_helper"

# The photo on a details page is the one thing every record type shares, and the
# rule is narrow: a record with a photo shows it in the left part of the identity
# card, and a record without one is laid out exactly as it was before photos
# existed. Both halves are asserted, because the second is the one that silently
# regresses.
class RecordPhotoDetailsTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @crop = data_url(Rails.root.join("db/photos/dark/landscape.jpg").binread)
  end

  PAGES = {
    "characters" => :universe_character_path,
    "locations" => :universe_location_path,
    "items" => :universe_item_path,
    "events" => :universe_event_path,
    "relations" => :universe_relation_path,
    "ownerships" => :universe_ownership_path,
    "character_tags" => :universe_character_tag_path,
    "location_tags" => :universe_location_tag_path,
    "item_tags" => :universe_item_tag_path,
    "event_tags" => :universe_event_tag_path,
    "relation_tags" => :universe_relation_tag_path,
    "ownership_tags" => :universe_ownership_tag_path
  }.freeze

  test "every record type with a details page shows its photo" do
    records = records_for_every_type

    PAGES.each do |name, helper|
      record = records.fetch(name)
      record.update!(photo_data: @crop)

      get public_send(helper, universe_slug: @universe.slug, id: record)

      assert_response :success, "#{name} details should render"
      assert_select "figure.record-photo img.record-photo-image", 1,
        "#{name} should show its photo in the identity card"
    end
  end

  test "a record without a photo shows no picture at all" do
    PAGES.each do |name, helper|
      record = records_for_every_type.fetch(name)
      assert_nil record.photo_id, "#{name} fixture unexpectedly carries a photo"

      get public_send(helper, universe_slug: @universe.slug, id: record)

      assert_response :success
      assert_select "figure.record-photo", 0, "#{name} should not render a photo it does not have"
    end
  end

  test "the photo is a square and sits beside the facts, not above them" do
    character = characters(:character_one)
    character.update!(photo_data: @crop)

    get universe_character_path(universe_slug: @universe.slug, id: character)

    # The picture is inside the identity card's row, in the column before the
    # facts, so the two sit side by side on a wide screen.
    assert_select ".surface-card .row .col-12.col-sm-5.col-md-4.col-lg-3 figure.record-photo", 1
    assert_select ".surface-card .row .col-12.col-sm-7.col-md-8.col-lg-9 dl.detail-facts", 1
    assert_select "figure.record-photo img[width=?][height=?]", "300", "300"
  end

  test "a record without a photo keeps the card exactly as it was" do
    character = characters(:character_one)

    get universe_character_path(universe_slug: @universe.slug, id: character)

    # No row, no columns, no picture: the identity block sits directly in the
    # card, which is what every details page looked like before photos.
    assert_select ".surface-card > .page-eyebrow", 1
    assert_select ".surface-card .row", 0
    assert_select ".surface-card > dl.detail-facts", 1
  end

  test "the image carries the record's name as its alternative text" do
    character = characters(:character_one)
    character.update!(photo_data: @crop)

    get universe_character_path(universe_slug: @universe.slug, id: character)

    assert_select "figure.record-photo img[alt=?]", "Photo of #{character.name}"
  end

  test "a guest sees a record's photo on a public universe" do
    character = characters(:character_one)
    character.update!(photo_data: @crop)

    get universe_character_path(universe_slug: @universe.slug, id: character)

    assert_response :success
    assert_select "figure.record-photo img", 1
  end

  test "the story-scoped pages show their photo too" do
    story = stories(:story_one)
    story.update!(photo_data: @crop)
    section = story.sections.first
    section.update!(photo_data: @crop)
    scene = story.scenes.first
    scene.update!(photo_data: @crop)
    section_tag = story.section_tags.first
    section_tag.update!(photo_data: @crop)
    scene_tag = story.scene_tags.first
    scene_tag.update!(photo_data: @crop)

    {
      "section" => :universe_story_section_path,
      "section tag" => :universe_story_section_tag_path,
      "scene tag" => :universe_story_scene_tag_path
    }.each do |label, helper|
      get public_send(helper, universe_slug: @universe.slug, story_id: story,
        id: { "section" => section, "section tag" => section_tag, "scene tag" => scene_tag }.fetch(label))

      assert_response :success, "#{label} details should render"
      assert_select "figure.record-photo img", 1, "#{label} should show its photo"
    end
  end

  test "the scene page shows its photo" do
    story = stories(:story_one)
    scene = story.scenes.first
    scene.update!(photo_data: @crop)

    get universe_story_scene_path(universe_slug: @universe.slug, story_id: story, id: scene)

    assert_response :success
    assert_select "figure.record-photo img", 1
  end

  test "the universe page shows its photo" do
    @universe.update!(photo_data: @crop)

    get universe_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select "figure.record-photo img", 1
  end

  test "the story page shows its photo" do
    story = stories(:story_one)
    story.update!(photo_data: @crop)

    get universe_story_path(universe_slug: @universe.slug, id: story)

    assert_response :success
    assert_select "figure.record-photo img", 1
  end

  private
    def records_for_every_type
      relation = Relation.create!(universe: @universe, character1: characters(:character_one), character2: characters(:character_two))
      ownership = Ownership.create!(universe: @universe, character: characters(:character_one), item: items(:item_one))

      {
        "characters" => characters(:character_one),
        "locations" => locations(:location_one),
        "items" => items(:item_one),
        "events" => events(:event_one),
        "relations" => relation,
        "ownerships" => ownership,
        "character_tags" => character_tags(:character_tag_one),
        "location_tags" => location_tags(:location_tag_one),
        "item_tags" => item_tags(:item_tag_one),
        "event_tags" => event_tags(:event_tag_one),
        "relation_tags" => RelationTag.create!(universe: @universe, name: "Kindred"),
        "ownership_tags" => OwnershipTag.create!(universe: @universe, name: "Carries")
      }
    end

    def data_url(bytes, type: "image/jpeg")
      "data:#{type};base64,#{Base64.strict_encode64(bytes)}"
    end
end
