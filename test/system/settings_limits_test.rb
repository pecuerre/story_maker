require "application_system_test_case"

# The Limits section's place in the browser. `SettingsControllerTest` owns the
# save itself — the stored value, the flash, and the cleared field's "no limit"
# answer — because a request is the contract and a toast that removes itself four
# seconds after it connects cannot be a reliable browser assertion in the parallel
# system suite. This file keeps what only a browser shows: the section appears
# beside the three browser sections for an operator and not for anybody else, and
# a guessed `?section=limits` cannot reach it.
class SettingsLimitsTest < ApplicationSystemTestCase
  test "an operator finds the Limits section and its field" do
    sign_in_via_form(users(:platform_operator))

    visit settings_path(section: "limits")

    assert_selector "h2#limits-title", text: "Limits"
    assert_selector "nav.settings-navigation a.active[aria-current=page]", text: "Limits"
    assert_selector "input[name=universe_creation_limit][value='#{PlatformSetting::DEFAULT_UNIVERSE_CREATION_LIMIT}']"
    assert_button "Save limits"
  end

  test "a plain reader sees the same three sections and cannot reach the fourth" do
    sign_in_via_form(users(:user_one))

    visit settings_path

    assert_selector "nav.settings-navigation a", text: "Limits", count: 0

    # A URL is not an authorization: the guessed section is treated as unrecognised
    # and lands on the first one, exactly as a typo would.
    visit settings_path(section: "limits")

    assert_selector "h2#appearance-title"
    assert_selector "input[name=universe_creation_limit]", count: 0
  end

  test "a guest sees the same three sections" do
    visit settings_path(section: "limits")

    assert_selector "h2#appearance-title"
    assert_selector "nav.settings-navigation a", text: "Limits", count: 0
  end
end
