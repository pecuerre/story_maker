require "application_system_test_case"

# The language flow is the one place where the server's answer and the browser's
# document are the same feature, the way the theme is: the layout renders
# `<html lang>` and the page's own copy comes from the request's locale, and a
# language change opts out of Turbo precisely so that a real page load replaces
# the whole document at once. Only a real browser can show that the attribute
# changed, that a Turbo navigation did not get in the way, and that the choice
# survives a navigation into the workspace.
#
# The root element's attributes are asserted with `assert_selector` rather than
# read straight out of the page. Both settings forms load a whole new document,
# and a selector assertion waits for it, where reading `getAttribute` the instant
# after a click can still see the document being replaced.
class SettingsLocaleTest < ApplicationSystemTestCase
  test "choosing Spanish repaints the document and the choice follows to a universe" do
    universe = universes(:universe_one)

    sign_in_via_form(users(:user_one))
    visit settings_url

    assert_current_path settings_path
    assert_selector "h2#appearance-title", text: "Appearance"
    assert_selector "html[lang='en']"

    click_link "Language"

    assert_current_path settings_path(section: "language")
    assert_selector "h2#language-title", text: "Language"
    assert_checked_field "English", checked: true

    choose "Español"
    click_button "Save language"

    # The whole document changed language, not only the body: `lang` is an
    # attribute on the root element, which a Turbo visit would have left alone.
    assert_selector "h2#language-title", text: "Idioma"
    assert_selector "html[lang='es']"
    assert_checked_field "Español", checked: true
    assert_selector ".alert-success", text: /El idioma ahora es/

    # The choice belongs to the browser, so it is still there on another page.
    click_link "Universe Maker"

    assert_current_path root_path
    assert_selector "html[lang='es']"

    click_link universe.name

    assert_selector "h1", text: universe.name
    assert_selector "html[lang='es']"
    # The section titles are uppercased by the stylesheet, so the rendered text
    # is compared without regard to case.
    assert_selector "nav.workspace-navigation h3", text: /Biblia del universo/i
  end

  test "the language is reversible and the theme is unaffected" do
    sign_in_via_form(users(:user_one))
    visit settings_path

    # The two preferences are independent: changing the theme does not disturb
    # the language, and the other way round. The section is visited directly
    # rather than clicked, so this case is about independence rather than the tab
    # strip, which the case above already covers.
    choose "Dark"
    click_button "Save theme"

    assert_selector "html[data-bs-theme='dark']"

    visit settings_path(section: "language")
    choose "Español"
    click_button "Save language"

    assert_selector "html[lang='es']"
    assert_selector "html[data-bs-theme='dark']"

    choose "English"
    # The page is now answering in Spanish, so the control that brings it back is
    # named in Spanish. That is the whole point: the reader reads the page they
    # are on.
    click_button "Guardar el idioma"

    assert_selector "html[lang='en']"
    assert_selector "html[data-bs-theme='dark']"

    visit settings_path
    assert_selector "h2#appearance-title", text: "Appearance"
  end
end
