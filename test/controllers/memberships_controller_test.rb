require "test_helper"

class MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_two)
    sign_in_as(users(:user_one))
  end

  test "owner can list members" do
    get universe_memberships_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: "Members"
    assert_select "form[action=?]", universe_memberships_path(universe_slug: @universe.slug)
  end

  test "owner can open the add member page" do
    get new_universe_membership_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: "Add member"
  end

  test "owner can grant membership" do
    assert_difference("UniverseMembership.count") do
      post universe_memberships_url(universe_slug: @universe.slug),
        params: { membership: { email_address: @user.email_address, access_level: "write" } }
    end

    assert_redirected_to universe_memberships_url(universe_slug: @universe.slug)
    assert_equal "write", UniverseMembership.last.access_level
  end

  test "unknown users are rejected" do
    assert_no_difference("UniverseMembership.count") do
      post universe_memberships_url(universe_slug: @universe.slug),
        params: { membership: { email_address: "missing@example.com", access_level: "read" } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "could not be found"
  end

  test "invalid access levels are rejected" do
    assert_no_difference("UniverseMembership.count") do
      post universe_memberships_url(universe_slug: @universe.slug),
        params: { membership: { email_address: @user.email_address, access_level: "owner" } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "not a valid access level"
  end

  test "delegated admins can manage memberships" do
    UniverseMembership.create!(universe: @universe, user: @user, access_level: :admin)
    sign_in_as(@user)

    get universe_memberships_url(universe_slug: @universe.slug)
    assert_response :success
    assert_select "h1", text: "Members"
  end

  test "ordinary members cannot manage memberships" do
    UniverseMembership.create!(universe: @universe, user: @user, access_level: :write)
    sign_in_as(@user)

    get universe_memberships_url(universe_slug: @universe.slug)
    assert_response :forbidden
  end

  test "membership ids cannot cross universe boundaries" do
    membership = UniverseMembership.create!(universe: universes(:universe_two), user: users(:user_one), access_level: :read)

    patch universe_membership_url(universe_slug: @universe.slug, id: membership),
      params: { membership: { access_level: "admin" } }

    assert_response :not_found
    assert_equal "read", membership.reload.access_level
  end

  test "invalid update levels are rejected" do
    membership = UniverseMembership.create!(universe: @universe, user: @user, access_level: :read)

    patch universe_membership_url(universe_slug: @universe.slug, id: membership),
      params: { membership: { access_level: "owner" } }

    assert_response :unprocessable_content
    assert_equal "read", membership.reload.access_level
  end

  test "owner can change and remove a membership" do
    membership = UniverseMembership.create!(universe: @universe, user: @user, access_level: :read)

    patch universe_membership_url(universe_slug: @universe.slug, id: membership),
      params: { membership: { access_level: "admin" } }
    assert_redirected_to universe_memberships_url(universe_slug: @universe.slug)
    assert_equal "admin", membership.reload.access_level

    assert_difference("UniverseMembership.count", -1) do
      delete universe_membership_url(universe_slug: @universe.slug, id: membership)
    end
    assert_redirected_to universe_memberships_url(universe_slug: @universe.slug)
  end
end
