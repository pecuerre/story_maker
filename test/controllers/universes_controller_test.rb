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

  test "index shows each visible universe's contents and recent activity" do
    get universes_url
    assert_response :success

    assert_select "td", text: /2 stories/
    assert_select "td", text: /11 entities/
    assert_select "td", text: /1 story/
    assert_select "td", text: /3 entities/
    assert_select "time", count: 2
  end

  test "an empty universe shows zero counts and no activity" do
    Universe.create!(owner: users(:user_one), name: "Empty", slug: "empty")

    get universes_url

    assert_select "td", text: "0 stories", count: 1
    assert_select "span.text-body-secondary", text: "—", count: 1
  end

  test "guests see public universes only on the index" do
    Universe.create!(owner: users(:user_one), name: "Private", slug: "private", private: true)
    sign_out

    get universes_url
    assert_response :success

    assert_select "a", text: "Universe one"
    assert_select "a", text: "Private", count: 0
  end

  test "the index does not recount every universe on every render" do
    sign_in_as(users(:user_one))

    counted = -> {
      count_queries(/FROM "(characters|locations|events|items|relations|ownerships|stories)"/) do
        get universes_url
      end
    }

    first = counted.call
    second = counted.call

    assert_equal first, second
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

  # --- the mutation budget (ADR 0028), which an admin sets from this form ---

  test "an admin can change the mutation limit" do
    patch universe_url(@universe), params: { universe: { mutation_limit: "5" } }

    assert_redirected_to universe_url(@universe)
    assert_equal 5, @universe.reload.mutation_limit
  end

  test "an admin can remove the limit, which is the blank field the form submits" do
    patch universe_url(@universe), params: { universe: { mutation_limit: "" } }

    assert_redirected_to universe_url(@universe)
    assert_nil @universe.reload[:mutation_limit]
    assert @universe.reload.mutations_unlimited?
  end

  test "a limit the request never mentions is not an answer, so an unrelated save cannot clear one" do
    @universe.update!(mutation_limit: 5)

    patch universe_url(@universe), params: { universe: { name: @universe.name } }, as: :json

    assert_response :ok
    assert_equal 5, @universe.reload.mutation_limit
  end

  test "a limit of zero is refused as a field error" do
    patch universe_url(@universe), params: { universe: { mutation_limit: "0" } }

    assert_response :unprocessable_content
    assert_select ".alert-danger[role=alert] li", text: /Mutation limit must be greater than 0/
    assert_equal Universe::DEFAULT_MUTATION_LIMIT, @universe.reload.mutation_limit
  end

  test "a limit that is not a number is refused in the JSON contract" do
    patch universe_url(@universe), params: { universe: { mutation_limit: "many" } }, as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body["mutation_limit"], "is not a number"
    assert_equal Universe::DEFAULT_MUTATION_LIMIT, @universe.reload.mutation_limit
  end

  test "a refused update keeps the limit the admin typed" do
    patch universe_url(@universe), params: { universe: { mutation_limit: "0" } }

    assert_response :unprocessable_content
    assert_select "input#universe_mutation_limit[value=?]", "0"
    assert_equal Universe::DEFAULT_MUTATION_LIMIT, @universe.reload.mutation_limit
  end

  test "an ordinary public contributor cannot change the mutation limit" do
    sign_in_as(users(:user_two))

    patch universe_url(@universe), params: { universe: { mutation_limit: "1" } }

    assert_response :forbidden
    assert_equal Universe::DEFAULT_MUTATION_LIMIT, @universe.reload.mutation_limit
  end

  test "a universe admin can change the mutation limit" do
    UniverseMembership.create!(universe: @universe, user: users(:user_two), access_level: :admin)
    sign_in_as(users(:user_two))

    patch universe_url(@universe), params: { universe: { mutation_limit: "2" } }

    assert_redirected_to universe_url(@universe)
    assert_equal 2, @universe.reload.mutation_limit
  end

  test "the edit form shows the stored limit, and a blank field when there is none" do
    # The field prints the *stored* setting rather than the number in force.
    # Rails' own binding asks the public reader for a record it read rather than
    # assigned, and that reader answers the default for an unlimited row — so the
    # default field would offer 60 to a universe whose admin deliberately chose
    # no limit, and submitting that form would impose it.
    @universe.update!(mutation_limit: 5)

    get edit_universe_url(@universe)

    assert_response :success
    assert_select "input#universe_mutation_limit[value=?]", "5"
    assert_select "input#universe_mutation_limit[type=number][min=?]", "1"

    @universe.update!(mutation_limit: nil)

    get edit_universe_url(@universe)

    # No `value` attribute at all, which is the empty field an admin clears and
    # saves to mean "no limit".
    assert_select "input#universe_mutation_limit:not([value])"
  end

  test "a new universe's form offers the default rather than a blank field" do
    get new_universe_url

    assert_response :success
    assert_select "input#universe_mutation_limit[value=?]", Universe::DEFAULT_MUTATION_LIMIT.to_s
  end

  # --- the per-group sub-limits (ADR 0029), from the same form ----------------

  test "an admin can change every per-group limit in one save" do
    patch universe_url(@universe), params: { universe: { photo_mutation_limit: "4",
      membership_mutation_limit: "6", discussion_mutation_limit: "8" } }

    assert_redirected_to universe_url(@universe)
    assert_equal 4, @universe.reload.photo_mutation_limit
    assert_equal 6, @universe.reload.membership_mutation_limit
    assert_equal 8, @universe.reload.discussion_mutation_limit
  end

  test "a cleared group limit is that group alone being unlimited" do
    patch universe_url(@universe), params: { universe: { photo_mutation_limit: "" } }

    assert_redirected_to universe_url(@universe)
    assert @universe.reload.mutation_group_unlimited?(:photo)
    assert_equal Universe::MUTATION_GROUP_LIMITS[:discussion], @universe.reload.discussion_mutation_limit,
      "clearing one ceiling must leave the others alone"
    assert_not @universe.reload.mutations_unlimited?
  end

  test "a group limit the request never mentions is not an answer" do
    @universe.update!(photo_mutation_limit: 5)

    patch universe_url(@universe), params: { universe: { name: @universe.name } }, as: :json

    assert_response :ok
    assert_equal 5, @universe.reload.photo_mutation_limit
  end

  test "a group limit of zero is refused as a field error" do
    patch universe_url(@universe), params: { universe: { discussion_mutation_limit: "0" } }

    assert_response :unprocessable_content
    assert_select ".alert-danger[role=alert] li", text: /Discussion mutation limit must be greater than 0/
    assert_equal Universe::MUTATION_GROUP_LIMITS[:discussion], @universe.reload.discussion_mutation_limit
  end

  test "an ordinary contributor cannot change a per-group limit" do
    sign_in_as(users(:user_two))

    patch universe_url(@universe), params: { universe: { photo_mutation_limit: "1" } }

    assert_response :forbidden
    assert_equal Universe::MUTATION_GROUP_LIMITS[:photo], @universe.reload.photo_mutation_limit
  end

  test "the form shows each stored group limit, and a blank field where there is none" do
    # The same binding rule as the overall budget, for the same reason: the reader
    # answers the default for an unlimited row, so letting Rails bind it would offer
    # a number an admin deliberately refused and submitting would impose it.
    @universe.update!(photo_mutation_limit: 5, membership_mutation_limit: nil)

    get edit_universe_url(@universe)

    assert_response :success
    assert_select "input#universe_photo_mutation_limit[value=?]", "5"
    assert_select "input#universe_photo_mutation_limit[type=number][min=?]", "1"
    assert_select "input#universe_membership_mutation_limit:not([value])"
    assert_select "input#universe_discussion_mutation_limit[value=?]",
      Universe::MUTATION_GROUP_LIMITS[:discussion].to_s
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
