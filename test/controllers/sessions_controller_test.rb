require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "opening the sign-in page remembers the page it was opened from" do
    universe = universes(:universe_one)

    get universe_url(universe)
    get new_session_path, headers: { "Referer" => universe_url(universe) }

    assert_response :success
    assert_equal universe_url(universe), session[:return_to_after_authenticating]
  end

  test "signing in from a remembered page returns to that page" do
    universe = universes(:universe_one)

    get new_session_path, headers: { "Referer" => universe_url(universe) }
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to universe_url(universe)
  end

  test "an external referer is not remembered as the return destination" do
    get new_session_path, headers: { "Referer" => "https://example.com/phishing" }

    assert_response :success
    assert_nil session[:return_to_after_authenticating]
  end

  test "a guest redirected from a write attempt returns to that page after signing in" do
    universe = universes(:universe_one)

    post universe_characters_path(universe_slug: universe.slug), params: { character: { name: "X" } }
    assert_redirected_to new_session_path
    follow_redirect!

    assert_equal universe_characters_url(universe_slug: universe.slug), session[:return_to_after_authenticating]

    post session_path, params: { email_address: @user.email_address, password: "password" }
    assert_redirected_to universe_characters_url(universe_slug: universe.slug)
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
    # With no story remembered, the top bar states the universe only: the story
    # link exists exactly while a story is current.
    assert_select "nav .navbar-nav a.nav-link[href=?]", universe_path(universe)
    assert_select "nav .navbar-nav .nav-item", 1
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
    assert_select "nav .navbar-nav a.nav-link[href=?]", universe_path(universe)
    assert_select "nav .navbar-nav .nav-item", 1
  end
end
