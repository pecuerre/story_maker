require "test_helper"

# The Drafting contract section: a browser display preference, not a universe
# setting. It decides only whether Scene pages draw the stored note, so these
# cases pin the settings flow and leave the Scene surfaces to
# `ScenesControllerTest`.
class SettingsDraftingContractTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:user_one) }

  test "the settings page offers a Drafting contract section beside Start page" do
    get settings_url

    assert_response :success
    assert_select "nav.settings-navigation a[href=?]", settings_path(section: "drafting_contract"),
      text: "Drafting contract"
    assert_select "h2#drafting-contract-title", count: 0

    get settings_url(section: "drafting_contract")

    assert_response :success
    assert_select "nav.settings-navigation a.active[aria-current=page]", text: "Drafting contract"
    assert_select "h2#drafting-contract-title", text: "Drafting contract"
    assert_select "h2#appearance-title", count: 0
    assert_select "h2#start-page-title", count: 0
  end

  test "showing the contract is the default and is the checked option" do
    get settings_url(section: "drafting_contract")

    assert_select "input[type=radio][name=drafting_contract][value=show][checked]", 1
    assert_select "input[type=radio][name=drafting_contract][value=hide][checked]", 0
    assert_select "label[for=drafting_contract_show]", text: /Show/
    assert_select "label[for=drafting_contract_hide]", text: /Hide/
  end

  test "hiding the contract stores the choice, confirms it, and is reversible" do
    patch settings_url(section: "drafting_contract"), params: { drafting_contract: "hide" }

    assert_response :see_other
    assert_redirected_to settings_url(section: "drafting_contract")
    follow_redirect!
    assert_select ".alert-success", text: /now hidden/
    assert_equal "hide", rendered_drafting_contract

    patch settings_url(section: "drafting_contract"), params: { drafting_contract: "show" }

    follow_redirect!
    assert_select ".alert-success", text: /now shown/
    assert_equal "show", rendered_drafting_contract
  end

  test "an unknown visibility is refused and leaves the stored choice alone" do
    patch settings_url(section: "drafting_contract"), params: { drafting_contract: "hide" }
    patch settings_url(section: "drafting_contract"), params: { drafting_contract: "sometimes" }

    assert_redirected_to settings_url(section: "drafting_contract")
    follow_redirect!
    assert_select ".alert-danger", text: /show or hide the drafting contract/
    assert_equal "hide", rendered_drafting_contract,
      "a refused request stores nothing, so the stored preference is exactly what it was"
  end

  # The preference is browser-owned, so it has to work for a guest with no
  # universe selected, like the other three.
  test "a guest can hide the contract on the landing page" do
    sign_out

    get settings_url(section: "drafting_contract")
    assert_response :success
    assert_select "h2#drafting-contract-title", text: "Drafting contract"

    patch settings_url(section: "drafting_contract"), params: { drafting_contract: "hide" }

    follow_redirect!
    assert_equal "hide", rendered_drafting_contract
  end

  private
    def rendered_drafting_contract
      css_select("input[name=drafting_contract][checked]").first&.[]("value")
    end
end
