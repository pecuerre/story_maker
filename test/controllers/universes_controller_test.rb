require "test_helper"

class UniversesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get universes_url
    assert_response :success
  end

  test "should get new" do
    get new_universe_url
    assert_response :success
  end

  test "should create universe" do
    assert_difference("Universe.count") do
      post universes_url, params: { universe: { name: @universe.name } }
    end

    assert_redirected_to universe_url(Universe.last)
    follow_redirect!
    assert_select ".alert-success", text: /successfully created/
  end

  test "should not create universe without a name" do
    assert_no_difference("Universe.count") do
      post universes_url, params: { universe: { name: "" } }
    end

    assert_response :unprocessable_content
  end

  test "should not create universe with a null visibility flag" do
    assert_no_difference("Universe.count") do
      post universes_url, params: { universe: { name: "Ambiguous", private: nil } }, as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["private"], "is not included in the list"
  end

  test "should not update universe with a null visibility flag" do
    patch universe_url(@universe), params: { universe: { private: nil } }, as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body["private"], "is not included in the list"
    assert_equal false, @universe.reload[:private]
  end

  test "should show universe" do
    get universe_url(@universe)
    assert_response :success
  end

  test "should get edit" do
    get edit_universe_url(@universe)
    assert_response :success
  end

  test "should update universe" do
    patch universe_url(@universe), params: { universe: { name: @universe.name } }
    assert_redirected_to universe_url(@universe)
  end

  test "an admin can change universe visibility" do
    patch universe_url(@universe), params: { universe: { private: "1" } }

    assert_redirected_to universe_url(@universe)
    assert @universe.reload.private?
  end

  test "an ordinary public contributor cannot change universe settings" do
    sign_in_as(users(:user_two))

    patch universe_url(@universe), params: { universe: { private: "1" } }

    assert_response :forbidden
    assert_not @universe.reload.private?
  end

  test "any signed-in user can contribute to a public universe" do
    sign_in_as(users(:user_two))

    assert_difference("Character.count") do
      post universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: "Public contributor" } },
        as: :json
    end
    assert_response :created
  end

  test "guests can read public universes" do
    sign_out

    get universe_url(@universe)
    assert_response :success

    get universe_characters_url(universe_slug: @universe.slug)
    assert_response :success
    assert_select ".page-actions button", count: 0
  end

  test "guests cannot create universes" do
    sign_out

    get new_universe_url
    assert_redirected_to new_session_path

    assert_no_difference("Universe.count") do
      post universes_url, params: { universe: { name: "Anonymous universe" } }
    end
    assert_redirected_to new_session_path
  end

  test "JSON visibility follows the universe policy" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private", slug: "private", private: true)
    sign_out

    get universes_url(format: :json)
    assert_response :success
    assert_not_includes response.parsed_body.map { |universe| universe["id"] }, private_universe.id

    get universe_url(private_universe, format: :json)
    assert_response :not_found

    sign_in_as(users(:user_two))
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)
    get universe_url(private_universe, format: :json)
    assert_response :success
  end

  test "guests can read public universe stories and sections" do
    sign_out

    get universe_story_url(universe_slug: @universe.slug, id: stories(:story_one))
    assert_response :success

    get universe_story_sections_url(universe_slug: @universe.slug, story_id: stories(:story_one))
    assert_response :success
  end

  test "guests cannot contribute to public universes" do
    sign_out

    assert_no_difference("Character.count") do
      post universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: "Anonymous character" } },
        as: :json
    end

    assert_redirected_to new_session_path
  end

  test "private universes are hidden from guests and non-members" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private", slug: "private", private: true)
    sign_out

    get universe_url(private_universe)
    assert_response :not_found
    private_response_body = response.body
    assert_nil response.headers["Location"]

    get universe_url(universe_slug: "missing")
    assert_response :not_found
    assert_equal private_response_body, response.body
    assert_nil response.headers["Location"]

    sign_in_as(users(:user_two))
    get universe_url(private_universe)
    assert_response :not_found

    assert_no_difference("Character.count") do
      post universe_characters_url(universe_slug: private_universe.slug),
        params: { character: { name: "Should not be visible" } },
        as: :json
    end
    assert_response :not_found
  end

  test "private universe members can read according to their level" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private", slug: "private", private: true)
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)
    sign_in_as(users(:user_two))

    get universe_url(private_universe)
    assert_response :success
    get universe_characters_url(universe_slug: private_universe.slug)
    assert_response :success
    assert_select ".page-actions button", count: 0

    assert_no_difference("Character.count") do
      post universe_characters_url(universe_slug: private_universe.slug),
        params: { character: { name: "Read-only character" } },
        as: :json
    end
    assert_response :forbidden
  end

  test "private universe writers and admins can contribute" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private", slug: "private", private: true)
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :write)
    sign_in_as(users(:user_two))

    assert_difference("Character.count") do
      post universe_characters_url(universe_slug: private_universe.slug),
        params: { character: { name: "Writer character" } },
        as: :json
    end
    assert_response :created
  end
end
