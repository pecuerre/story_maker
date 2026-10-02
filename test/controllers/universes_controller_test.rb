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
    assert_select ".alert-success", text: /#{I18n.t("universes.flash.created")}/
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

  test "a duplicate name renders an address field error instead of raising" do
    Universe.create!(owner: users(:user_one), name: "Duplicate")

    assert_no_difference("Universe.count") do
      post universes_url, params: { universe: { name: "Duplicate" } }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger[role=alert] li", text: /Slug has already been taken/
  end

  test "a taken address is a field error in the JSON contract" do
    Universe.create!(owner: users(:user_one), name: "Duplicate")

    assert_no_difference("Universe.count") do
      post universes_url, params: { universe: { name: "Duplicate" } }, as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["slug"], "has already been taken"
  end

  test "an explicit address disambiguates a duplicate name" do
    Universe.create!(owner: users(:user_one), name: "Duplicate")

    assert_difference("Universe.count") do
      post universes_url, params: { universe: { name: "Duplicate", slug: "duplicate-two" } }
    end

    universe = Universe.order(:id).last
    assert_equal "duplicate-two", universe.slug
    assert_redirected_to universe_url(universe)
  end

  test "a rename into a taken address re-renders the form" do
    Universe.create!(owner: users(:user_one), name: "Taken", slug: "taken")

    patch universe_url(@universe), params: { universe: { name: "Taken" } }

    assert_response :unprocessable_content
    assert_select ".alert-danger[role=alert] li", text: /Slug has already been taken/
    assert_equal "one", @universe.reload.slug
  end

  test "a refused update keeps the address the author typed" do
    Universe.create!(owner: users(:user_one), name: "Taken", slug: "taken")

    patch universe_url(@universe), params: { universe: { name: @universe.name, slug: "taken" } }

    assert_response :unprocessable_content
    assert_select ".alert-danger[role=alert] li", text: /Slug has already been taken/
    assert_select "input#universe_slug[value=?]", "taken"
  end

  test "a refused create leaves the optional address blank" do
    post universes_url, params: { universe: { name: "" } }

    assert_response :unprocessable_content
    assert_select "input#universe_slug[value='']"
  end

  test "an unrelated update keeps the address the universe is published under" do
    patch universe_url(@universe), params: { universe: { name: @universe.name, private: "1", slug: "" } }

    assert_redirected_to universe_url(@universe)
    assert_equal "one", @universe.reload.slug
    assert @universe.reload.private?
  end

  test "an author can republish a universe under a chosen address" do
    patch universe_url(@universe), params: { universe: { name: @universe.name, slug: "renamed_address" } }

    assert_redirected_to universe_url(@universe.reload)
    assert_equal "renamed-address", @universe.reload.slug
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

  test "an admin can change the collaboration mode" do
    patch universe_url(@universe), params: { universe: { collaboration_mode: "wikipedia" } }

    assert_redirected_to universe_url(@universe)
    assert @universe.reload.wikipedia?
    assert @universe.draft_based?
  end

  test "a collaboration mode the application has no behaviour for is refused" do
    patch universe_url(@universe), params: { universe: { collaboration_mode: "consensus" } }

    assert_response :unprocessable_content
    assert_select ".alert-danger[role=alert] li", text: /Collaboration mode is not included in the list/
    assert @universe.reload.direct?
  end

  test "an unknown collaboration mode is refused in the JSON contract" do
    patch universe_url(@universe), params: { universe: { collaboration_mode: "consensus" } }, as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body["collaboration_mode"], "is not included in the list"
    assert @universe.reload.direct?
  end

  test "an ordinary public contributor cannot change the collaboration mode" do
    sign_in_as(users(:user_two))

    patch universe_url(@universe), params: { universe: { collaboration_mode: "wikipedia" } }

    assert_response :forbidden
    assert @universe.reload.direct?
  end

  test "a universe admin can change the collaboration mode" do
    UniverseMembership.create!(universe: @universe, user: users(:user_two), access_level: :admin)
    sign_in_as(users(:user_two))

    patch universe_url(@universe), params: { universe: { collaboration_mode: "github" } }

    assert_redirected_to universe_url(@universe)
    assert @universe.reload.github?
  end

  test "the edit form offers every collaboration mode and the one in use" do
    get edit_universe_url(@universe)

    assert_response :success
    assert_select "select#universe_collaboration_mode option", count: Universe::COLLABORATION_MODES.size
    assert_select "select#universe_collaboration_mode option[selected]", text: "Direct — a change is saved straight away"
  end

  test "a universe can be created in a draft-based collaboration mode" do
    post universes_url, params: { universe: { name: "Reviewed", collaboration_mode: "github" } }

    universe = Universe.order(:id).last
    assert universe.github?
    assert_redirected_to universe_url(universe)
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
