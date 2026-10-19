require "test_helper"

# The API surface is authenticated by a bearer token rather than a session, so no
# `sign_in_as` is used here: every request carries `Authorization: Bearer …`.
class Api::RelationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
    @token = api_tokens(:token_one)   # issued for universe one only
    @bearer = "alpha-api-token-one"
  end

  def headers
    { "Authorization" => "Bearer #{@bearer}" }
  end

  test "index lists the universe's relations as json" do
    get api_universe_relations_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_equal [ "relation-one" ],
      response.parsed_body.map { |relation| relation["slug"] }
  end

  test "index is empty for a universe without relations" do
    @universe.relations.destroy_all

    get api_universe_relations_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_empty response.parsed_body
  end

  test "show returns one relation as json" do
    get api_universe_relation_url(universe_slug: @universe.slug, id: relations(:relation_one)),
      headers: headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal relations(:relation_one).id, body["id"]
    assert_equal relations(:relation_one).character1_id, body["character1_id"]
    assert_equal relations(:relation_one).character2_id, body["character2_id"]
    assert_equal [ relation_tags(:relation_tag_one).id ], body["relation_tag_ids"]
  end

  test "a token issued for one universe is refused on another" do
    get api_universe_relations_url(universe_slug: @other_universe.slug), headers: headers, as: :json

    assert_response :not_found
  end

  test "a request without a bearer token is refused" do
    get api_universe_relations_url(universe_slug: @universe.slug), as: :json

    assert_response :unauthorized
  end

  test "an unknown bearer token is refused" do
    get api_universe_relations_url(universe_slug: @universe.slug),
      headers: { "Authorization" => "Bearer does-not-exist" }, as: :json

    assert_response :unauthorized
  end

  test "a revoked bearer token is refused" do
    api_tokens(:token_one).revoke!

    get api_universe_relations_url(universe_slug: @universe.slug),
      headers: headers, as: :json

    assert_response :unauthorized
  end

  test "create creates a relation as json" do
    assert_difference("Relation.count") do
      post api_universe_relations_url(universe_slug: @universe.slug),
        params: { relation: { name: "Api relation", character1_id: characters(:character_one).id,
          character2_id: characters(:character_two).id } },
        headers: headers, as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "Api relation", body["name"]
    assert_equal characters(:character_one).id, body["character1_id"]
    assert_equal characters(:character_two).id, body["character2_id"]
  end

  test "create rejects a character from another universe" do
    assert_no_difference("Relation.count") do
      post api_universe_relations_url(universe_slug: @universe.slug),
        params: { relation: { character1_id: characters(:character_other_universe).id,
          character2_id: characters(:character_two).id } },
        headers: headers, as: :json
    end

    assert_response :unprocessable_content
  end

  test "update updates a relation as json" do
    patch api_universe_relation_url(universe_slug: @universe.slug, id: relations(:relation_one)),
      params: { relation: { name: "Renamed via api" } },
      headers: headers, as: :json

    assert_response :success
    assert_equal "Renamed via api", relations(:relation_one).reload.name
  end

  test "destroy deletes a relation as json" do
    assert_difference("Relation.count", -1) do
      delete api_universe_relation_url(universe_slug: @universe.slug, id: relations(:relation_one)),
        headers: headers, as: :json
    end

    assert_response :no_content
  end

  test "a non-json relation mutation is refused before it writes" do
    assert_no_difference("Relation.count") do
      post api_universe_relations_url(universe_slug: @universe.slug),
        params: { relation: { name: "No json" } },
        headers: headers
    end

    assert_response :not_acceptable
  end
end
