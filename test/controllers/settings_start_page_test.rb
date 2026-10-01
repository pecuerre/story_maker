require "test_helper"

# The Start page section: the third platform preference, and the section that
# answers "where does signing in take me".
#
# It exists as its own tab rather than joining Appearance or Language because
# none of the other two describe it: a theme and a language change how a page is
# drawn, and this changes which page is opened. The browser case, where the
# preference is actually followed across a sign-in, is in
# `test/system/settings_start_page_test.rb`.
class SettingsStartPageTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:user_one) }

  test "the settings page offers a Start page section beside Appearance and Language" do
    get settings_url

    assert_response :success
    assert_select "nav.settings-navigation a.active[aria-current=page]", text: "Appearance"
    assert_select "nav.settings-navigation a[href=?]", settings_path(section: "language"), text: "Language"
    assert_select "nav.settings-navigation a[href=?]", settings_path(section: "start_page"), text: "Start page"
    assert_select "h2#start-page-title", count: 0

    get settings_url(section: "start_page")

    assert_response :success
    assert_select "nav.settings-navigation a.active[aria-current=page]", text: "Start page"
    assert_select "h2#start-page-title", text: "Start page"
    assert_select "h2#appearance-title", count: 0
    assert_select "h2#language-title", count: 0
  end

  # Remembering is the default, so a reader who has never opened this section is
  # already answering with it.
  test "remembering the last story is the default and is the checked option" do
    get settings_url(section: "start_page")

    assert_response :success
    assert_select "input[type=radio][name=start_page][value=remember][checked]", 1
    assert_select "input[type=radio][name=start_page][value=universes][checked]", 0
    assert_select "label[for=start_page_remember]", text: /My last story/
    assert_select "label[for=start_page_universes]", text: /The universes list/
  end

  test "the two options say what each one does" do
    get settings_url(section: "start_page")

    assert_select "label[for=start_page_remember]", text: /Open the universe and story you were last working in/
    assert_select "label[for=start_page_universes]", text: /Always start from the list of universes/
  end

  test "choosing the universes list stores the choice and answers with it" do
    patch settings_url(section: "start_page"), params: { start_page: "universes" }

    assert_redirected_to settings_url(section: "start_page")
    follow_redirect!
    assert_select ".alert-success", text: /The universes list/
    assert_equal "universes", rendered_start_page
  end

  # The choice is reversible, and going back to remembering restores the stored
  # destination rather than forgetting it.
  test "choosing the last story again is stored and reversible" do
    patch settings_url(section: "start_page"), params: { start_page: "universes" }
    patch settings_url(section: "start_page"), params: { start_page: "remember" }

    follow_redirect!
    assert_select ".alert-success", text: /My last story/
    assert_equal "remember", rendered_start_page
  end

  # Choosing the universes list contradicts a stored destination, so the stored
  # one goes with it rather than being left to disagree with the preference.
  test "choosing the universes list forgets the stored destination" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    remember_destination(universe: universe, story: story)

    patch settings_url(section: "start_page"), params: { start_page: "universes" }

    # The observable consequence: signing in again no longer resumes that story.
    sign_out
    get new_session_path
    post session_path, params: { email_address: users(:user_one).email_address, password: "password" }
    assert_redirected_to root_url
  end

  test "choosing the last story keeps the stored destination" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    remember_destination(universe: universe, story: story)

    patch settings_url(section: "start_page"), params: { start_page: "remember" }

    sign_out
    get new_session_path
    post session_path, params: { email_address: users(:user_one).email_address, password: "password" }
    assert_redirected_to universe_story_url(universe_slug: universe.slug, id: story)
  end

  # A hand-built request may carry one preference or several, and a refused value
  # must not apply the others: a request that is refused stores nothing.
  test "an unknown start page is refused and leaves the stored preference alone" do
    patch settings_url(section: "start_page"), params: { start_page: "universes" }
    patch settings_url(section: "start_page"), params: { start_page: "everything" }

    assert_redirected_to settings_url(section: "start_page")
    follow_redirect!
    assert_select ".alert-danger", text: /Choose either your last story or the universes list/
    assert_equal "universes", rendered_start_page,
      "a refused request stores nothing, so the stored preference is exactly what it was"
  end

  test "a refused start page does not apply a theme carried in the same request" do
    patch settings_url(section: "start_page"), params: { start_page: "everything", theme: "dark" }

    # The refusal redirects to the Start page section, which has no theme
    # control, so the theme is read from its own section.
    follow_redirect!
    assert_equal "remember", rendered_start_page

    get settings_url
    assert_select "input[type=radio][name=theme][value=light][checked]", 1,
      "a theme carried by a refused request was not applied"
    assert_select "input[type=radio][name=theme][value=dark][checked]", 0
  end

  test "a start page and a theme are saved together in one request" do
    patch settings_url(section: "start_page"), params: { start_page: "universes", theme: "dark" }

    follow_redirect!
    assert_select ".alert-success", text: /The universes list/
    assert_equal "universes", rendered_start_page

    get settings_url
    assert_select "input[type=radio][name=theme][value=dark][checked]", 1
  end

  test "a request carrying no preference at all is refused" do
    patch settings_url(section: "start_page"), params: {}

    assert_response :bad_request
  end

  # The section is a browser-owned preference, so it has to work before a
  # universe is chosen and with no account at all, like the other two.
  test "a guest can choose a start page on the landing page" do
    sign_out

    get settings_url(section: "start_page")

    assert_response :success
    assert_select "h2#start-page-title", text: "Start page"

    patch settings_url(section: "start_page"), params: { start_page: "universes" }

    follow_redirect!
    assert_equal "universes", rendered_start_page
  end

  test "the save returns to the section it was made from" do
    patch settings_url(section: "start_page"), params: { start_page: "universes" }
    assert_redirected_to settings_url(section: "start_page")

    patch settings_url, params: { theme: "dark" }
    assert_redirected_to settings_url

    patch settings_url(section: "language"), params: { locale: "es" }
    assert_redirected_to settings_url(section: "language")
  end

  # An unrecognised section is the page's own address rather than an error, so a
  # stale or mistyped query parameter cannot produce a blank page.
  test "an unknown section falls back to Appearance" do
    get settings_url(section: "nonsense")

    assert_response :success
    assert_select "h2#appearance-title", text: "Appearance"
    assert_select "nav.settings-navigation a.active[aria-current=page]", text: "Appearance"
  end

  private
    # The preference is read back off the rendered form rather than out of the
    # cookie jar, which is the shape `SettingsControllerTest` already uses: what
    # the reader is shown is the thing worth asserting.
    def rendered_start_page
      css_select("input[name=start_page][checked]").first&.[]("value")
    end

    # The signed cookie the browser would present next, written the way the
    # application writes it.
    def remember_destination(universe:, story:)
      jar = ActionDispatch::TestRequest.create.cookie_jar
      RememberedDestination.write(jar, user: users(:user_one), universe: universe, story: story)
      cookies[RememberedDestination::COOKIE_NAME.to_s] = jar[RememberedDestination::COOKIE_NAME]
    end
end
