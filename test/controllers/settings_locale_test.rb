require "test_helper"

# Choosing a language, and the page really answering in it.
#
# These are request tests rather than a check that `I18n.locale` changed: the
# contract a reader depends on is the *rendered page*, and a locale that is set
# but not threaded into a partial is invisible to a locale assertion. The
# browser case is in `test/system/settings_locale_test.rb`; what only a browser
# can show is the full-page reload changing `<html lang>`, which is why both
# exist.
class SettingsLocaleTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:user_one) }

  test "the settings page offers a Language section beside Appearance" do
    get settings_url

    assert_response :success
    assert_select "nav.settings-navigation a.active[aria-current=page]", text: "Appearance"
    assert_select "nav.settings-navigation a[href=?]", settings_path(section: "language"), text: "Language"
    assert_select "h2#language-title", count: 0

    get settings_url(section: "language")

    assert_response :success
    assert_select "nav.settings-navigation a.active[aria-current=page]", text: "Language"
    assert_select "h2#language-title", text: "Language"
    assert_select "h2#appearance-title", count: 0
  end

  test "each option is named in its own language and shows the current choice" do
    get settings_url(section: "language")

    assert_select "input[type=radio][name=locale][value=en][checked]"
    assert_select "input[type=radio][name=locale][value=es][checked]", 0
    assert_select "label[for=locale_es]", text: /Español/
    assert_select "label[for=locale_en]", text: /English/
  end

  test "choosing Spanish renders the next page in Spanish" do
    # The form submits to the section it is on, and the save returns the reader
    # to that same section rather than moving them to the other tab.
    patch settings_url(section: "language"), params: { locale: "es" }

    assert_response :see_other
    assert_redirected_to settings_url(section: "language")

    follow_redirect!
    assert_response :success
    assert_select "h2#language-title", text: "Idioma"
    # The document says so too, which is what a screen reader and a browser's
    # own hyphenation read.
    assert_equal "es", rendered_lang
    assert_select "input[type=radio][name=locale][value=es][checked]"
  end

  test "the choice follows the reader to a universe page" do
    universe = universes(:universe_one)
    patch settings_url, params: { locale: "es" }

    get universe_url(universe)

    assert_response :success
    assert_equal "es", rendered_lang
    assert_select ".access-notice", text: /acceso/i if response.body.include?("access-notice")
    # The workspace chrome is translated, not just the settings page.
    assert_select "nav.workspace-navigation h3", text: "Biblia del universo"
    assert_select "nav.navbar .dropdown button", text: "Cuenta"
  end

  test "a theme and a language can be saved together and both stick" do
    patch settings_url, params: { theme: "dark", locale: "es" }

    assert_response :see_other

    get settings_url

    assert_equal "dark", rendered_theme
    assert_equal "es", rendered_lang
  end

  test "the language is reversible" do
    patch settings_url, params: { locale: "es" }
    patch settings_url, params: { locale: "en" }

    get settings_url
    assert_equal "en", rendered_lang
    assert_select "h2#appearance-title", text: "Appearance"
  end

  test "an unknown language is refused and leaves the stored preference alone" do
    patch settings_url(section: "language"), params: { locale: "es" }

    patch settings_url(section: "language"), params: { locale: "klingon" }

    assert_response :see_other
    assert_redirected_to settings_url(section: "language")

    follow_redirect!
    # The refusal is itself in Spanish, because the reader's stored language
    # survived the refused request.
    assert_select ".alert-danger", text: /Elige uno de los idiomas/
    assert_equal "es", rendered_lang
  end

  test "a refused language does not apply a theme carried in the same request" do
    patch settings_url(section: "language"), params: { theme: "dark", locale: "klingon" }

    follow_redirect!
    assert_equal "light", rendered_theme
    assert_equal "en", rendered_lang
  end

  test "a mutation with neither preference is a bad request" do
    patch settings_url

    assert_response :bad_request
  end

  test "a hand-edited language cookie cannot put anything but a known locale in the page" do
    get settings_url, headers: { "Cookie" => "um_locale=es\" lang=\"xx" }

    assert_response :success
    assert_equal "en", rendered_lang

    patch settings_url, params: { locale: "es" }
    get settings_url, headers: { "Cookie" => "um_locale=klingon; other=1" }

    assert_equal "en", rendered_lang
  end

  test "a guest can choose a language" do
    sign_out
    patch settings_url, params: { locale: "es" }

    get root_url

    assert_response :success
    assert_equal "es", rendered_lang
  end

  test "the confirmation is written in the language that was just chosen" do
    patch settings_url(section: "language"), params: { locale: "es" }

    follow_redirect!
    # The reader has already said which language they want; answering them in
    # the one they are leaving is the one case where it is guaranteed wrong.
    assert_select ".alert-success", text: /El idioma ahora es Español/
  end

  test "the go back destination is not overwritten by visiting the Language section" do
    universe = universes(:universe_one)

    # First visit from a real page, so the destination is stored.
    get settings_url, headers: { "Referer" => universe_url(universe) }
    assert_select ".page-actions a[href=?]", universe_url(universe)

    # The section is the same page with a query parameter, so returning to it
    # from itself must not replace the remembered destination.
    get settings_url(section: "language"), headers: { "Referer" => settings_url(section: "language") }

    assert_response :success
    assert_select ".page-actions a[href=?]", universe_url(universe)
  end

  private
    def rendered_lang
      Nokogiri::HTML(response.body).at_css("html")["lang"]
    end

    def rendered_theme
      Nokogiri::HTML(response.body).at_css("html")["data-bs-theme"]
    end
end
