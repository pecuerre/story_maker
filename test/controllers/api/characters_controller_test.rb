require "test_helper"

# The API surface is authenticated by a bearer token rather than a session, so no
# `sign_in_as` is used here: every request carries `Authorization: Bearer …`.
class Api::CharactersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
    @token = api_tokens(:token_one)   # issued for universe one only
    @bearer = "alpha-api-token-one"
  end

  def headers
    { "Authorization" => "Bearer #{@bearer}" }
  end

  test "index lists the universe's characters as json" do
    get api_universe_characters_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_equal [ "Character one", "Character three", "Character two" ],
      response.parsed_body.map { |character| character["name"] }.sort
  end

  test "index is empty for a universe without characters" do
    @universe.characters.destroy_all

    get api_universe_characters_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_empty response.parsed_body
  end

  test "show returns one character as json" do
    get api_universe_character_url(universe_slug: @universe.slug, id: characters(:character_one)),
      headers: headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal characters(:character_one).id, body["id"]
    assert_equal characters(:character_one).name, body["name"]
    assert_nil body["summary"]
    assert_nil body["description"]
    assert_nil body["pronouns"]
    assert_nil body["aliases"]
  end

  test "create creates a character as json" do
    assert_difference("Character.count") do
      post api_universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: "Api character", pronouns: "they/them", aliases: "The Gate, Ari",
          summary: "Via the API", description: "## Wants\n\nA safe road.",
          faction_ids: [ factions(:faction_two).id ] } },
        headers: headers, as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "Api character", body["name"]
    assert_equal "they/them", body["pronouns"]
    assert_equal "The Gate, Ari", body["aliases"]
    assert_equal "Via the API", body["summary"]
    assert_equal "## Wants\n\nA safe road.", body["description"]
    assert_equal [], body["character_tag_ids"]
    assert_equal [ factions(:faction_two).id ], body["faction_ids"]
    character = Character.find(body["id"])
    assert_equal @universe.id, character.universe_id
  end

  test "create rejects a tag from another universe" do
    foreign_tag = character_tags(:character_tag_three)

    assert_no_difference("Character.count") do
      post api_universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: "Mis-scoped", character_tag_ids: [ foreign_tag.id ] } },
        headers: headers, as: :json
    end

    assert_response :unprocessable_content
  end

  test "create rejects a Faction from another universe" do
    assert_no_difference("Character.count") do
      post api_universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: "Mis-scoped faction", faction_ids: [ factions(:faction_other_universe).id ] } },
        headers: headers, as: :json
    end

    assert_response :unprocessable_content
  end

  test "update updates a character as json" do
    patch api_universe_character_url(universe_slug: @universe.slug, id: characters(:character_one)),
      params: { character: { name: "Renamed via api" } },
      headers: headers, as: :json

    assert_response :success
    assert_equal "Renamed via api", characters(:character_one).reload.name
  end

  test "destroy deletes a character as json" do
    assert_difference("Character.count", -1) do
      delete api_universe_character_url(universe_slug: @universe.slug, id: characters(:character_two)),
        headers: headers, as: :json
    end

    assert_response :no_content
  end

  test "a token issued for one universe is refused on another" do
    get api_universe_characters_url(universe_slug: @other_universe.slug), headers: headers, as: :json

    assert_response :not_found
  end

  test "a request without a bearer token is refused" do
    get api_universe_characters_url(universe_slug: @universe.slug), as: :json

    assert_response :unauthorized
  end

  test "an unknown bearer token is refused" do
    get api_universe_characters_url(universe_slug: @universe.slug),
      headers: { "Authorization" => "Bearer does-not-exist" }, as: :json

    assert_response :unauthorized
  end

  test "a revoked bearer token is refused" do
    api_tokens(:token_one).revoke!

    get api_universe_characters_url(universe_slug: @universe.slug),
      headers: headers, as: :json

    assert_response :unauthorized
  end

  test "a non-json mutation is refused before it writes" do
    assert_no_difference("Character.count") do
      post api_universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: "No json" } },
        headers: headers
    end

    assert_response :not_acceptable
  end

  test "a token's mutations stop at its own budget inside the universe's" do
    # The universe's budget (60) is untouched here: the token's own ceiling of 2
    # is what refuses the third mutation.
    api_tokens(:token_one).update!(mutation_limit: 2)

    2.times do |n|
      post api_universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: "Token budget #{n}" } },
        headers: headers, as: :json

      assert_response :created
    end

    assert_no_difference("Character.count") do
      post api_universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: "Over the token budget" } },
        headers: headers, as: :json
    end

    assert_response :too_many_requests
    assert_equal 3, Rails.cache.read("#{MutationThrottle::KEY_PREFIX}:token:#{api_tokens(:token_one).id}").to_i
  end

  test "a token's reads stop at the read ceiling" do
    api_tokens(:token_one).update!(mutation_limit: 2)

    2.times do
      get api_universe_characters_url(universe_slug: @universe.slug),
        headers: headers, as: :json

      assert_response :success
    end

    get api_universe_characters_url(universe_slug: @universe.slug),
      headers: headers, as: :json

    assert_response :too_many_requests
  end
end
