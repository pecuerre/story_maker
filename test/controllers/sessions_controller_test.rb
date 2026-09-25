require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
    set_cookie = Array(response.headers["Set-Cookie"]).join("\n")
    assert_match(/HttpOnly/i, set_cookie)
    assert_match(/SameSite=Lax/i, set_cookie)
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "destroy clears remembered stories" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    sign_in_as(users(:user_one))

    get universe_story_url(universe_slug: universe.slug, id: story)
    assert_equal({ universe.id.to_s => story.id }, session[:current_story_ids])

    delete session_path

    assert_nil session[:current_story_ids]
  end

  test "starting a session clears story selections before account switching" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    sign_in_as(users(:user_one))
    get universe_story_url(universe_slug: universe.slug, id: story)

    post session_path, params: { email_address: users(:user_two).email_address, password: "password" }
    get universe_url(universe)

    assert_response :success
    assert_select "span.navbar-context", text: "Select"
  end

  test "invalid authentication clears stale story selections" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    sign_in_as(users(:user_one))
    get universe_story_url(universe_slug: universe.slug, id: story)
    Current.session.destroy!

    get universe_url(universe)

    assert_response :success
    assert_empty cookies[:session_id]
    assert_nil session[:current_story_ids]
    assert_select "span.navbar-context", text: "Select"
  end
end
