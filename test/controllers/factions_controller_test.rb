require "test_helper"

class FactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @faction = factions(:faction_one)
    @tag = faction_tags(:faction_tag_one)
    sign_in_as(users(:user_one))
  end

  test "index lists factions and exposes the profile editor" do
    get universe_factions_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".page-header h1", text: "Factions"
    assert_select ".entity-title", text: @faction.name
    assert_select "button[data-action='modal-form#open'][data-modal-form-url=?]",
      universe_faction_path(universe_slug: @universe.slug, id: @faction)
    assert_select "textarea[name='faction[actual_aims]']"
    assert_select "select[name='faction[faction_tag_ids][]']"
    assert_select "nav.content-tabs a[href=?]", universe_factions_path(universe_slug: @universe.slug), text: "Factions"
    assert_select "nav.content-tabs a[href=?]",
      universe_faction_tag_path(universe_slug: @universe.slug, id: @tag, from: "workspace"), text: @tag.name
  end

  test "creates and updates a faction as JSON with optional tags" do
    attributes = {
      name: "The Lantern Circle",
      mission: "Keep the roads safe",
      actual_aims: "Control the crossings",
      structure: "Three local stewards",
      internal_divisions: "The stewards disagree on tolls",
      resources: "A chain of roadside inns",
      would_never: "Abandon a traveler",
      would_absolutely: "Close a road to protect its people",
      faction_tag_ids: [ @tag.id ]
    }

    assert_difference("Faction.count") do
      post universe_factions_url(universe_slug: @universe.slug), params: { faction: attributes }, as: :json
    end

    assert_response :created
    faction = Faction.order(:id).last
    assert_equal "the-lantern-circle", faction.slug
    assert_equal [ @tag.id ], faction.faction_tag_ids
    assert_equal "Control the crossings", response.parsed_body["actual_aims"]

    patch universe_faction_url(universe_slug: @universe.slug, id: faction),
      params: { faction: { mission: "Guide travelers safely", faction_tag_ids: [ "" ] } }, as: :json

    assert_response :success
    assert_equal "Guide travelers safely", faction.reload.mission
    assert_empty faction.faction_tag_ids
  end

  test "rejects faction tags from another universe" do
    foreign_tag = faction_tags(:faction_tag_two)

    assert_no_difference("Faction.count") do
      post universe_factions_url(universe_slug: @universe.slug),
        params: { faction: { name: "Mis-scoped", faction_tag_ids: [ foreign_tag.id ] } }, as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "must belong to the same universe" ], response.parsed_body["faction_tags"]
  end

  test "details show each faction profile field" do
    get universe_faction_url(universe_slug: @universe.slug, id: @faction)

    assert_response :success
    assert_select ".detail-fact", text: /A public promise/
    assert_select ".detail-fact", text: /A private goal/
    assert_select ".detail-fact", text: /Council-led/
    assert_select ".detail-fact", text: /The elders disagree/
    assert_select ".detail-fact", text: /Access to a library/
    assert_select ".detail-fact", text: /Betray an ally/
    assert_select ".detail-fact", text: /Protect its own/
  end

  test "a guest can read factions but sees no mutation controls" do
    sign_out

    get universe_factions_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select "button[data-action='modal-form#destroy']", count: 0
    assert_select "[data-modal-form-target='modal']", count: 0
  end

  test "private-universe access follows the read and write membership levels" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Faction access", slug: "faction-access", private: true)
    faction = private_universe.factions.create!(name: "Private faction")

    sign_out
    sign_in_as(users(:user_two))
    get universe_factions_url(universe_slug: private_universe.slug)
    assert_response :not_found

    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)
    get universe_factions_url(universe_slug: private_universe.slug)
    assert_response :success
    assert_select "button[data-action='modal-form#open']", count: 0

    assert_no_difference("Faction.count") do
      post universe_factions_url(universe_slug: private_universe.slug),
        params: { faction: { name: "Not writable" } }, as: :json
    end
    assert_response :forbidden
    assert Faction.exists?(faction.id)
  end

  test "the JSON-only mutations reject HTML before writing" do
    assert_no_difference("Faction.count") do
      post universe_factions_url(universe_slug: @universe.slug), params: { faction: { name: "HTML" } }
    end
    assert_response :not_acceptable
  end

  test "deleting a faction soft-deletes it and retains it for restore" do
    delete universe_faction_url(universe_slug: @universe.slug, id: @faction), as: :json

    assert_response :no_content
    assert_nil Faction.find_by(id: @faction.id)
    assert Faction.with_deleted.find(@faction.id).deleted?
  end
end
