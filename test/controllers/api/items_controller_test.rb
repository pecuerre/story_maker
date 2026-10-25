require "test_helper"

# The API surface is authenticated by a bearer token rather than a session, so no
# `sign_in_as` is used here: every request carries `Authorization: Bearer …`.
class Api::ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
    @token = api_tokens(:token_one)   # issued for universe one only
    @bearer = "alpha-api-token-one"
  end

  def headers
    { "Authorization" => "Bearer #{@bearer}" }
  end

  test "index lists the universe's items as json" do
    get api_universe_items_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_equal [ "Item one", "Item two" ],
      response.parsed_body.map { |item| item["name"] }.sort
  end

  test "index is empty for a universe without items" do
    @universe.items.destroy_all

    get api_universe_items_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_empty response.parsed_body
  end

  test "show returns one item as json" do
    get api_universe_item_url(universe_slug: @universe.slug, id: items(:item_one)),
      headers: headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal items(:item_one).id, body["id"]
    assert_equal items(:item_one).name, body["name"]
    assert_equal [ item_tags(:item_tag_one).id ], body["item_tag_ids"]
    assert_nil body["parent_id"]
    assert_equal items(:item_one).position, body["position"]
    # Every profile answer is part of the record's JSON, including the ones this
    # fixture leaves blank, so an API consumer sees the same shape for every item.
    assert_equal "Opens the sealed gate", body["what_it_does"]
    assert_equal "The northern forge", body["origin"]
    assert_equal "Gate-key", body["jargon"]
    assert_equal Item::PROFILE_FIELDS.map(&:to_s).sort, (body.keys & Item::PROFILE_FIELDS.map(&:to_s)).sort
  end

  test "a token issued for one universe is refused on another" do
    get api_universe_items_url(universe_slug: @other_universe.slug), headers: headers, as: :json

    assert_response :not_found
  end

  test "a request without a bearer token is refused" do
    get api_universe_items_url(universe_slug: @universe.slug), as: :json

    assert_response :unauthorized
  end

  test "an unknown bearer token is refused" do
    get api_universe_items_url(universe_slug: @universe.slug),
      headers: { "Authorization" => "Bearer does-not-exist" }, as: :json

    assert_response :unauthorized
  end

  test "a revoked bearer token is refused" do
    api_tokens(:token_one).revoke!

    get api_universe_items_url(universe_slug: @universe.slug),
      headers: headers, as: :json

    assert_response :unauthorized
  end
end
