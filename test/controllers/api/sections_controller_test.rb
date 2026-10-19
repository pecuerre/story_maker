require "test_helper"

# The API surface is authenticated by a bearer token rather than a session, so no
# `sign_in_as` is used here: every request carries `Authorization: Bearer …`.
class Api::SectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
    @story = stories(:story_one)
    @token = api_tokens(:token_one)   # issued for universe one only
    @bearer = "alpha-api-token-one"
  end

  def headers
    { "Authorization" => "Bearer #{@bearer}" }
  end

  test "index lists the story's sections as json" do
    get api_universe_story_sections_url(universe_slug: @universe.slug, story_id: @story.id),
      headers: headers, as: :json

    assert_response :success
    assert_equal [ "Section one", "Section two" ],
      response.parsed_body.map { |section| section["name"] }.sort
  end

  test "index is empty for a story without sections" do
    @story.sections.destroy_all

    get api_universe_story_sections_url(universe_slug: @universe.slug, story_id: @story.id),
      headers: headers, as: :json

    assert_response :success
    assert_empty response.parsed_body
  end

  test "show returns one section as json" do
    get api_universe_story_section_url(universe_slug: @universe.slug, story_id: @story.id,
      id: sections(:section_one)), headers: headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal sections(:section_one).id, body["id"]
    assert_equal sections(:section_one).name, body["name"]
    assert_equal [ section_tags(:section_tag_one).id ], body["section_tag_ids"]
    assert_nil body["parent_id"]
    assert_equal sections(:section_one).position, body["position"]
  end

  test "a token issued for one universe is refused on another" do
    get api_universe_story_sections_url(universe_slug: @other_universe.slug, story_id: @story.id),
      headers: headers, as: :json

    assert_response :not_found
  end

  test "a request without a bearer token is refused" do
    get api_universe_story_sections_url(universe_slug: @universe.slug, story_id: @story.id), as: :json

    assert_response :unauthorized
  end

  test "an unknown bearer token is refused" do
    get api_universe_story_sections_url(universe_slug: @universe.slug, story_id: @story.id),
      headers: { "Authorization" => "Bearer does-not-exist" }, as: :json

    assert_response :unauthorized
  end

  test "a revoked bearer token is refused" do
    api_tokens(:token_one).revoke!

    get api_universe_story_sections_url(universe_slug: @universe.slug, story_id: @story.id),
      headers: headers, as: :json

    assert_response :unauthorized
  end
end
