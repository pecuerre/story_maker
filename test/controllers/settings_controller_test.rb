require "test_helper"

# Settings is the one platform-level page: it is not universe-scoped, so it has to
# answer for a guest, for a signed-in user, and with no universe selected at all.
# The theme it stores is a signed cookie that the layout reads back on the next
# request, so these cases pin the observable contract — what the browser keeps is
# what the next page renders — instead of the cookie's own encoding.
class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "a guest reaches the page with no universe selected and sees the light default" do
    get settings_url

    assert_response :success
    assert_select "h1", text: "Settings"
    assert_equal "light", rendered_theme
    assert_select "nav.settings-navigation a[aria-current=page]", text: "Appearance"
    assert_select "input[type=radio][name=theme][value=light][checked]"
    assert_select "input[type=radio][name=theme][value=dark][checked]", 0
  end

  test "the page is reachable without a universe and does not open a workspace" do
    sign_in_as users(:user_one)

    get settings_url

    assert_response :success
    assert_select "aside.workspace-sidebar", 0
    assert_select "aside.right-sidebar", 0
    # A platform page is not a Configuration entry in the right utility sidebar;
    # the top bar is its single home.
    assert_select "nav.navbar a[href=?]", settings_path, count: 1
  end

  test "choosing dark remembers the choice and renders it" do
    patch settings_url, params: { theme: "dark" }

    assert_response :see_other
    assert_redirected_to settings_path

    follow_redirect!
    assert_response :success
    assert_equal "dark", rendered_theme
    assert_select "input[type=radio][name=theme][value=dark][checked]"
    assert_select "input[type=radio][name=theme][value=light][checked]", 0
  end

  test "the choice follows the reader into a universe page and back to the landing page" do
    universe = universes(:universe_one)
    sign_in_as users(:user_one)
    patch settings_url, params: { theme: "dark" }

    get universe_url(universe)

    assert_response :success
    assert_equal "dark", rendered_theme

    get universes_url

    assert_equal "dark", rendered_theme
  end

  test "the dark choice is reversible" do
    patch settings_url, params: { theme: "dark" }
    patch settings_url, params: { theme: "light" }

    assert_response :see_other

    follow_redirect!
    assert_equal "light", rendered_theme
  end

  test "an unknown theme is refused and leaves the stored preference alone" do
    patch settings_url, params: { theme: "dark" }

    patch settings_url, params: { theme: "chartreuse" }

    assert_response :see_other
    assert_redirected_to settings_path
    follow_redirect!
    assert_select ".alert-danger", text: /light or the dark theme/
    # The refusal is reported, not applied.
    assert_equal "dark", rendered_theme
  end

  test "a mutation without a theme is a bad request" do
    patch settings_url

    assert_response :bad_request
  end

  test "a hand-edited theme cookie cannot put anything but a known theme in the page" do
    get settings_url, headers: { "Cookie" => "um_theme=chartreuse\" data-bs-theme=\"dark" }

    assert_response :success
    assert_equal "light", rendered_theme

    patch settings_url, params: { theme: "dark" }
    get settings_url, headers: { "Cookie" => "um_theme=chartreuse; other=1" }

    assert_equal "light", rendered_theme
  end

  test "the top bar links to settings for a guest and marks the current page" do
    get settings_url

    # Settings lives inside the account menu, so the menu button carries the
    # current-page marker rather than a standalone settings link.
    assert_select "nav .dropdown button[aria-current=page]", text: "Account"
    assert_select "nav .dropdown a[href=?]", settings_path, text: /Settings/

    get universes_url

    assert_select "nav .dropdown a[href=?]", settings_path, text: /Settings/
    assert_select "nav .dropdown button[aria-current=page]", count: 0
  end

  test "the settings page offers a go back link to the page it was opened from" do
    universe = universes(:universe_one)

    get universe_url(universe)
    get settings_url, headers: { "Referer" => universe_url(universe) }

    assert_select ".page-actions a[href=?]", universe_url(universe), text: /Go back/
  end

  test "the go back link falls back to the landing page without a referer" do
    get settings_url

    assert_select ".page-actions a[href=?]", root_url, text: /Go back/
  end

  test "the go back link ignores an external referer" do
    get settings_url, headers: { "Referer" => "https://example.com/phishing" }

    assert_select ".page-actions a[href=?]", root_url, text: /Go back/
  end

  test "saving the theme keeps the go back destination" do
    universe = universes(:universe_one)

    get settings_url, headers: { "Referer" => universe_url(universe) }
    patch settings_url, params: { theme: "dark" }

    assert_redirected_to settings_url
    follow_redirect!
    assert_select ".page-actions a[href=?]", universe_url(universe), text: /Go back/
  end

  private
    # The theme the server rendered onto the root element of the last response,
    # which is what the browser paints and what the choice has to survive.
    def rendered_theme
      Nokogiri::HTML(response.body).at_css("html")["data-bs-theme"]
    end
end
