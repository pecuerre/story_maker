require "test_helper"

# Token management is an HTML flow: a reader lists their own API tokens for a
# universe and revokes any one of them. A token belongs to its account, so one
# reader never sees or revokes another reader's credential — anything else is a
# 404, the same way a private universe hides itself from a reader it does not list.
class ApiTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_one)
    sign_in_as(@user)
  end

  test "index lists the account's own tokens for the universe" do
    get universe_api_tokens_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: I18n.t("api_tokens.index.title")

    assert_select "td", text: "Token one"
    assert_select "td", text: "Token three"

    # User two's tokens never appear on user one's page, in either universe.
    refute_select "td", text: "Token two"
    refute_select "td", text: "Token four"
  end

  test "index shows each token's prefix, status, and last use" do
    get universe_api_tokens_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "td", text: "alpha-ap"
    assert_select "td", text: I18n.t("api_tokens.index.status.active")
  end

  test "destroy revokes one of the account's own tokens" do
    assert_difference -> { ApiToken.where(revoked_at: nil).count }, -1 do
      delete universe_api_token_url(universe_slug: @universe.slug, id: api_tokens(:token_one))
    end

    assert_redirected_to universe_api_tokens_url(universe_slug: @universe.slug)
    assert_equal I18n.t("api_tokens.flash.revoked"), flash[:notice]
    assert_predicate api_tokens(:token_one).reload, :revoked?
  end

  test "destroy refuses another account's token for this universe with 404" do
    assert_no_difference -> { ApiToken.count } do
      delete universe_api_token_url(universe_slug: @universe.slug, id: api_tokens(:token_four))
    end

    assert_response :not_found
    refute api_tokens(:token_four).reload.revoked?
  end

  test "destroy refuses a token issued for another universe with 404" do
    assert_no_difference -> { ApiToken.count } do
      delete universe_api_token_url(universe_slug: @universe.slug, id: api_tokens(:token_two))
    end

    assert_response :not_found
    refute api_tokens(:token_two).reload.revoked?
  end
end
