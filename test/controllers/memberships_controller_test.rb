require "test_helper"

# The Members workspace in the default (English) locale.
#
# The page's own copy is asserted through `I18n.t` rather than as a literal,
# because these strings are chrome: a literal here would be a second place that
# has to change when the copy does, and would keep passing if the key behind it
# were renamed. `WorkspaceLocaleTest` is the other half — it asserts the same
# pages answer in Spanish.
class MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_two)
    sign_in_as(users(:user_one))
  end

  test "owner can list members" do
    get universe_memberships_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: I18n.t("memberships.index.title")
    assert_select "form[action=?]", universe_memberships_path(universe_slug: @universe.slug)
  end

  # Every row prints a name, an address, and an aria label, so the users have to
  # arrive with the memberships. What is asserted is that the count does not
  # change with the number of rows: the queries the layout and `Current` add are
  # a fixed number and are deliberately not pinned here.
  test "adding a member does not add a query for that member" do
    UniverseMembership.create!(universe: @universe, user: @user, access_level: :read)

    with_one = count_queries(/FROM "users"/) do
      get universe_memberships_url(universe_slug: @universe.slug)
    end

    third = User.create!(name: "User Three", email_address: "three@example.com", password: "password")
    UniverseMembership.create!(universe: @universe, user: third, access_level: :read)

    with_two = count_queries(/FROM "users"/) do
      get universe_memberships_url(universe_slug: @universe.slug)
    end

    assert_response :success
    assert_equal with_one, with_two
  end

  test "owner can open the add member page" do
    get new_universe_membership_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: I18n.t("memberships.new.title")
  end

  test "owner can grant membership" do
    assert_difference("UniverseMembership.count") do
      post universe_memberships_url(universe_slug: @universe.slug),
        params: { membership: { email_address: @user.email_address, access_level: "write" } }
    end

    assert_redirected_to universe_memberships_url(universe_slug: @universe.slug)
    assert_equal I18n.t("memberships.flash.granted"), flash[:notice]
    assert_equal "write", UniverseMembership.last.access_level
  end

  test "unknown users are rejected" do
    assert_no_difference("UniverseMembership.count") do
      post universe_memberships_url(universe_slug: @universe.slug),
        params: { membership: { email_address: "missing@example.com", access_level: "read" } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("memberships.errors.email_not_found")
  end

  test "invalid access levels are rejected" do
    assert_no_difference("UniverseMembership.count") do
      post universe_memberships_url(universe_slug: @universe.slug),
        params: { membership: { email_address: @user.email_address, access_level: "owner" } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("memberships.errors.invalid_access_level")
  end

  test "delegated admins can manage memberships" do
    UniverseMembership.create!(universe: @universe, user: @user, access_level: :admin)
    sign_in_as(@user)

    get universe_memberships_url(universe_slug: @universe.slug)
    assert_response :success
    assert_select "h1", text: I18n.t("memberships.index.title")
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
    assert_equal I18n.t("memberships.flash.updated"), flash[:notice]
    assert_equal "admin", membership.reload.access_level

    assert_difference("UniverseMembership.count", -1) do
      delete universe_membership_url(universe_slug: @universe.slug, id: membership)
    end
    assert_redirected_to universe_memberships_url(universe_slug: @universe.slug)
    assert_equal I18n.t("memberships.flash.removed"), flash[:notice]
  end

  test "delegated admin cannot demote themselves" do
    membership = UniverseMembership.create!(universe: @universe, user: @user, access_level: :admin)
    sign_in_as(@user)

    patch universe_membership_url(universe_slug: @universe.slug, id: membership),
      params: { membership: { access_level: "write" } }

    assert_redirected_to root_path
    assert_equal I18n.t("memberships.flash.own_change_refused"), flash[:alert]
    assert_equal "admin", membership.reload.access_level
  end

  test "delegated admin cannot remove themselves" do
    membership = UniverseMembership.create!(universe: @universe, user: @user, access_level: :admin)
    sign_in_as(@user)

    assert_no_difference("UniverseMembership.count") do
      delete universe_membership_url(universe_slug: @universe.slug, id: membership)
    end

    assert_redirected_to root_path
    assert_equal I18n.t("memberships.flash.own_removal_refused"), flash[:alert]
    assert membership.reload.persisted?
  end

  test "own membership row hides change and remove controls" do
    UniverseMembership.create!(universe: @universe, user: @user, access_level: :admin)
    sign_in_as(@user)

    get universe_memberships_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "input[type=submit][value=?]", I18n.t("memberships.index.save"), count: 0
    assert_select "button", text: I18n.t("memberships.index.remove"), count: 0
    assert_select "td.text-end", text: I18n.t("memberships.index.you")
  end

  test "other membership rows keep change and remove controls" do
    UniverseMembership.create!(universe: @universe, user: @user, access_level: :read)

    get universe_memberships_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "input[type=submit][value=?]", I18n.t("memberships.index.save")
    assert_select "button", text: I18n.t("memberships.index.remove")
  end
end
