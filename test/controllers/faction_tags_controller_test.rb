require "test_helper"

class FactionTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @tag = faction_tags(:faction_tag_one)
    sign_in_as(users(:user_one))
  end

  test "index renders the Faction taxonomy tree" do
    get universe_faction_tags_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".page-header h1", text: "Faction tags"
    assert_select "li.taxonomy-node[data-node-id=?]", @tag.id.to_s
    assert_select "a[href=?]", universe_faction_tag_path(universe_slug: @universe.slug, id: @tag), text: /Details/
  end

  test "creates a faction tag through JSON and shows its assigned factions" do
    assert_difference("FactionTag.count") do
      post universe_faction_tags_url(universe_slug: @universe.slug),
        params: { faction_tag: { name: "Political", description: "Power-seeking groups", show_in_menu: "1" } }, as: :json
    end

    assert_response :created
    created = FactionTag.order(:id).last
    assert_equal "political", created.slug
    assert created.show_in_menu?

    get universe_faction_tag_url(universe_slug: @universe.slug, id: @tag)
    assert_response :success
    assert_select "a[href=?]", universe_faction_path(universe_slug: @universe.slug, id: factions(:faction_one)),
      text: factions(:faction_one).name
  end

  test "a workspace visit keeps the Factions tabs on a menu tag page" do
    get universe_faction_tag_url(universe_slug: @universe.slug, id: @tag, from: "workspace")

    assert_response :success
    assert_select "nav.content-tabs a.active[aria-current=page]",
      href: universe_faction_tag_path(universe_slug: @universe.slug, id: @tag, from: "workspace"),
      text: @tag.name
    assert_select "nav.content-tabs a[href=?]",
      universe_factions_path(universe_slug: @universe.slug), text: "Factions"
  end

  test "a foreign parent is rejected and a foreign tag is not found" do
    foreign_tag = faction_tags(:faction_tag_two)

    assert_no_difference("FactionTag.count") do
      post universe_faction_tags_url(universe_slug: @universe.slug),
        params: { faction_tag: { name: "Mis-scoped child", parent_id: foreign_tag.id } }, as: :json
    end
    assert_response :unprocessable_content
    assert response.parsed_body["parent"].present?

    get universe_faction_tag_url(universe_slug: @universe.slug, id: foreign_tag)
    assert_response :not_found
  end

  test "guests can read the taxonomy but cannot mutate it" do
    sign_out

    get universe_faction_tags_url(universe_slug: @universe.slug)
    assert_response :success
    assert_select "button[data-action='taxonomy-tree#open']", count: 0

    sign_in_as(users(:user_one))
    assert_no_difference("FactionTag.count") do
      post universe_faction_tags_url(universe_slug: @universe.slug), params: { faction_tag: { name: "HTML" } }
    end
    assert_response :not_acceptable
  end
end
