require "test_helper"

# "Remember last story": a reader who signs in with nothing to return to is sent
# back to the universe and story they were last working in.
#
# The rule that makes this safe is that a story is only ever a landing page
# because it was explicitly chosen once. There is still no fallback to the
# universe's first story, and every way the remembered value can be unusable has
# to answer the universes list rather than a dead or forbidden page.
class RememberedStartTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:user_one)
    @universe = universes(:universe_one)
    @story = stories(:story_one)
  end

  test "a reader with a remembered story lands on it after signing in" do
    remember_destination(user: @user, universe: @universe, story: @story)

    sign_in_from_the_sign_in_page

    assert_redirected_to universe_story_url(universe_slug: @universe.slug, id: @story)
  end

  test "the remembered story follows the reader to that story's own pages" do
    remember_destination(user: @user, universe: @universe, story: @story)

    sign_in_from_the_sign_in_page
    follow_redirect!

    assert_response :success
    assert_select "h1", @story.name
    assert_select ".sidebar-story-name", @story.name
  end

  # A page the reader asked to return to still wins. The preference only answers
  # the question "and if there is nothing to return to?".
  test "a page to return to takes precedence over the remembered story" do
    remember_destination(user: @user, universe: @universe, story: @story)

    get new_session_path, headers: { "Referer" => universe_url(@universe) }
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to universe_url(@universe)
  end

  test "with the preference turned off the universes list is the landing page" do
    remember_destination(user: @user, universe: @universe, story: @story)
    choose_universes_list

    sign_in_from_the_sign_in_page

    assert_redirected_to root_url
  end

  test "a reader with no remembered destination lands on the universes list" do
    sign_in_from_the_sign_in_page

    assert_redirected_to root_url
  end

  test "a destination stored by another account is not used" do
    remember_destination(user: users(:user_two), universe: universes(:universe_two), story: stories(:story_two))

    sign_in_from_the_sign_in_page(user: @user)

    assert_redirected_to root_url
  end

  # The remembered universe may since have been made private to somebody else.
  # The destination must answer the universes list rather than redirect to a page
  # this account cannot open.
  test "a remembered universe this account cannot read falls back to the universes list" do
    private_universe = Universe.create!(owner: users(:user_two), name: "Private to user two",
      slug: "private-to-two", private: true)
    remember_destination(user: @user, universe: private_universe, story: nil)

    sign_in_from_the_sign_in_page(user: @user)

    assert_redirected_to root_url
  end

  test "a deleted story falls back to its universe rather than a dead link" do
    remember_destination(user: @user, universe: @universe, story: @story)
    @story.soft_delete

    sign_in_from_the_sign_in_page

    assert_redirected_to universe_url(@universe)
  end

  # The whole point of the setting is that it survives a new login, which the
  # per-session story map cannot do: signing out and back in must still land on
  # the same story.
  test "the remembered story survives signing out and back in" do
    sign_in_as(@user)
    get universe_story_url(universe_slug: @universe.slug, id: @story)

    assert cookies[RememberedDestination::COOKIE_NAME].present?

    sign_out
    sign_in_from_the_sign_in_page

    assert_redirected_to universe_story_url(universe_slug: @universe.slug, id: @story)
  end

  # `set_current_story` runs on every request inside a universe; rewriting the
  # cookie each time would put a Set-Cookie header on every page view.
  test "browsing one story does not rewrite the remembered destination on every page" do
    sign_in_as(@user)
    get universe_story_url(universe_slug: @universe.slug, id: @story)

    cookies_before = cookie_value(RememberedDestination::COOKIE_NAME)
    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)

    assert_equal cookies_before, cookie_value(RememberedDestination::COOKIE_NAME)
    assert_no_match(/um_last_scope/, Array(response.headers["Set-Cookie"]).join("\n"))
  end

  # A search must not become a destination: typing in the search box is reading,
  # not choosing a story.
  test "a search does not change the remembered destination" do
    sign_in_as(@user)
    get universe_story_url(universe_slug: @universe.slug, id: @story)
    cookies_before = cookie_value(RememberedDestination::COOKIE_NAME)

    get search_path, params: { q: "Secrets" }

    assert_response :success
    assert_equal cookies_before, cookie_value(RememberedDestination::COOKIE_NAME)
  end

  # A guest has no account for a destination to be bound to.
  test "a guest is not given a remembered destination" do
    get universe_story_url(universe_slug: @universe.slug, id: @story)

    assert_equal "", cookie_value(RememberedDestination::COOKIE_NAME).to_s
  end

  private
    def sign_in_from_the_sign_in_page(user: @user)
      get new_session_path
      post session_path, params: { email_address: user.email_address, password: "password" }
    end

    def remember_destination(user:, universe:, story:)
      jar = ActionDispatch::TestRequest.create.cookie_jar
      RememberedDestination.write(jar, user: user, universe: universe, story: story)
      cookies[RememberedDestination::COOKIE_NAME.to_s] = jar[RememberedDestination::COOKIE_NAME]
    end

    def choose_universes_list
      jar = ActionDispatch::TestRequest.create.cookie_jar
      AppStartPage.write(jar, "universes")
      cookies[AppStartPage::COOKIE_NAME.to_s] = jar[AppStartPage::COOKIE_NAME]
    end

    # The raw cookie value the browser would present on the next request. An
    # integration test's jar holds the value as sent, so comparing it is enough
    # to tell whether the application rewrote the cookie.
    def cookie_value(name)
      cookies[name.to_s]
    end
end
