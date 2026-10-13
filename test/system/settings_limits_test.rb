require "application_system_test_case"

# The Limits section in a real browser, which is the only place this setting is
# reachable: `test/controllers/mutation_throttle_test.rb` proves the stored value
# and the authorization, and `test/models/platform_setting_test.rb` proves what
# `NULL` means. What only a browser shows is that the section appears beside the
# three browser sections for an operator and not for anybody else, that the number
# field is submitted by the real button, and that a cleared field reaches the server
# as "no limit" rather than as an empty number.
#
# The tab strip is the interesting half. `settings_sections` decides which sections
# exist for the reader, so a section that is not offered is also a section a guessed
# `?section=limits` cannot reach — an operator flag that only hid a control would
# still answer a URL.
class SettingsLimitsTest < ApplicationSystemTestCase
  test "an operator finds the section, saves a number, and it survives a reload" do
    sign_in_via_form(users(:platform_operator))

    visit settings_path(section: "limits")
    assert_selector "h2#limits-title", text: "Limits"
    assert_selector "nav.settings-navigation a.active[aria-current=page]", text: "Limits"
    assert_selector "input[name=universe_creation_limit][value='#{PlatformSetting::DEFAULT_UNIVERSE_CREATION_LIMIT}']"

    fill_in "New universes per hour", with: "7"
    click_button "Save limits"

    assert_selector ".alert-success", text: /7/
    assert_equal 7, PlatformSetting.current.universe_creation_limit

    # Stored rather than merely posted: a real page load reads it back.
    visit settings_path(section: "limits")
    assert_field "New universes per hour", with: "7"
  end

  test "clearing the field stores no limit and the field reopens empty" do
    PlatformSetting.create!(universe_creation_limit: 4)
    sign_in_via_form(users(:platform_operator))

    visit settings_path(section: "limits")
    fill_in "New universes per hour", with: ""
    click_button "Save limits"

    # The confirmation names "no limit" rather than the number the reader would
    # substitute for a row storing `NULL`.
    assert_selector ".alert-success", text: /no limit/
    assert PlatformSetting.current.universe_creations_unlimited?

    visit settings_path(section: "limits")
    assert_field "New universes per hour", with: ""
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
