require "test_helper"

# The API surface is authenticated by a bearer token rather than a session, so no
# `sign_in_as` is used here: every request carries `Authorization: Bearer …`.
class Api::OwnershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
    @token = api_tokens(:token_one)   # issued for universe one only
    @bearer = "alpha-api-token-one"
  end

  def headers
    { "Authorization" => "Bearer #{@bearer}" }
  end

  test "index lists the universe's ownerships as json" do
    get api_universe_ownerships_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_equal [ "ownership-one" ],
      response.parsed_body.map { |ownership| ownership["slug"] }
  end

  test "index is empty for a universe without ownerships" do
    @universe.ownerships.destroy_all

    get api_universe_ownerships_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_empty response.parsed_body
  end

  test "show returns one ownership as json" do
    get api_universe_ownership_url(universe_slug: @universe.slug, id: ownerships(:ownership_one)),
      headers: headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal ownerships(:ownership_one).id, body["id"]
    assert_equal ownerships(:ownership_one).item_id, body["item_id"]
    assert_equal ownerships(:ownership_one).character_id, body["character_id"]
    assert_equal [ ownership_tags(:ownership_tag_one).id ], body["ownership_tag_ids"]
  end

  test "a token issued for one universe is refused on another" do
    get api_universe_ownerships_url(universe_slug: @other_universe.slug), headers: headers, as: :json

    assert_response :not_found
  end

  test "a request without a bearer token is refused" do
    get api_universe_ownerships_url(universe_slug: @universe.slug), as: :json

    assert_response :unauthorized
  end

  test "an unknown bearer token is refused" do
    get api_universe_ownerships_url(universe_slug: @universe.slug),
      headers: { "Authorization" => "Bearer does-not-exist" }, as: :json

    assert_response :unauthorized
  end

  test "a revoked bearer token is refused" do
    api_tokens(:token_one).revoke!

    get api_universe_ownerships_url(universe_slug: @universe.slug),
      headers: headers, as: :json

    assert_response :unauthorized
  end

  test "create creates an ownership as json" do
    assert_difference("Ownership.count") do
      post api_universe_ownerships_url(universe_slug: @universe.slug),
        params: { ownership: { name: "Api ownership", item_id: items(:item_one).id,
          character_id: characters(:character_one).id } },
        headers: headers, as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "Api ownership", body["name"]
    assert_equal items(:item_one).id, body["item_id"]
    assert_equal characters(:character_one).id, body["character_id"]
  end

  test "create rejects a record from another universe" do
    item = @other_universe.items.create!(name: "Foreign item")
    assert_no_difference("Ownership.count") do
      post api_universe_ownerships_url(universe_slug: @universe.slug),
        params: { ownership: { item_id: item.id, character_id: characters(:character_one).id } },
        headers: headers, as: :json
    end

    assert_response :unprocessable_content
  end

  test "update updates an ownership as json" do
    patch api_universe_ownership_url(universe_slug: @universe.slug, id: ownerships(:ownership_one)),
      params: { ownership: { name: "Renamed via api" } },
      headers: headers, as: :json

    assert_response :success
    assert_equal "Renamed via api", ownerships(:ownership_one).reload.name
  end

  test "destroy deletes an ownership as json" do
    assert_difference("Ownership.count", -1) do
      delete api_universe_ownership_url(universe_slug: @universe.slug, id: ownerships(:ownership_one)),
        headers: headers, as: :json
    end

    assert_response :no_content
  end

  test "a non-json ownership mutation is refused before it writes" do
    assert_no_difference("Ownership.count") do
      post api_universe_ownerships_url(universe_slug: @universe.slug),
        params: { ownership: { name: "No json" } },
        headers: headers
    end

    assert_response :not_acceptable
  end
end
