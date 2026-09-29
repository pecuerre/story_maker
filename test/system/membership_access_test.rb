require "application_system_test_case"

# Browser coverage for the Members workspace, which is the only place universe
# access is managed. The grant journey has to prove two things: the row appears
# with its level, and the level is real — the member who was just granted access
# can write in the universe, while a read-only member cannot, and the Members
# page and its link stay admin-only. (The request tests own the exact status
# codes; a browser can only see what the refusal looks like.)
#
# The universe is private on purpose: in a public universe every signed-in user
# already has write access, so a membership level could not be observed here.
class MembershipAccessTest < ApplicationSystemTestCase
  setup do
    @owner = users(:user_one)
    @member = users(:user_two)
    @universe = Universe.create!(owner: @owner, name: "Browser members universe", slug: "browser-members", private: true)
  end

  test "an owner grants write access and the row appears with its level" do
    sign_in_via_form(@owner)
    visit universe_memberships_path(universe_slug: @universe.slug)
    assert_stimulus_loaded

    assert_selector "h1", text: "Members"
    assert_no_selector "td", text: @member.email_address

    fill_in "Email address", with: @member.email_address
    select "Write", from: "Access level"
    click_button "Grant access"

    assert_selector "td", text: @member.email_address, wait: REFRESH_WAIT
    within "tr", text: @member.email_address do
      assert_selector "select", text: "Write"
    end
    assert UniverseMembership.exists?(universe: @universe, user: @member, access_level: :write)
  end

  test "an unknown address is refused with the reason and grants nothing" do
    sign_in_via_form(@owner)
    visit universe_memberships_path(universe_slug: @universe.slug)
    assert_stimulus_loaded

    assert_no_difference("UniverseMembership.count") do
      fill_in "Email address", with: "nobody@example.com"
      select "Read", from: "Access level"
      click_button "Grant access"
    end

    # The summary is the shared one every workspace renders, so its sentence is
    # the shared copy rather than a second hand-written variant.
    assert_selector ".alert-danger[role=alert]", text: "prevented this access from being saved"
    assert_selector ".alert-danger[role=alert] li", text: /could not be found/
  end

  test "a granted member can write in the universe but cannot reach the Members page" do
    UniverseMembership.create!(universe: @universe, user: @member, access_level: :write)

    sign_in_via_form(@member)
    visit universe_characters_path(universe_slug: @universe.slug)

    assert_selector "button", text: "Add character"
    assert_no_selector ".access-notice"

    # Members is the admin-only half of Configuration, so a contributor is offered
    # the tag workspace but not the access manager.
    within "nav[aria-label='Universe configuration and tools']" do
      assert_selector "a", text: "Tags"
      assert_no_selector "a", text: "Members"
    end

    visit universe_memberships_path(universe_slug: @universe.slug)
    assert_no_selector "h1", text: "Members"
    assert_no_selector "table"
  end

  test "a read-only member is told the access level and offered no mutation" do
    UniverseMembership.create!(universe: @universe, user: @member, access_level: :read)

    sign_in_via_form(@member)
    visit universe_characters_path(universe_slug: @universe.slug)

    assert_selector ".access-notice", text: "read-only"
    assert_no_selector "button", text: "Add character"
    assert_no_selector ".modal"

    within "nav[aria-label='Universe configuration and tools']" do
      assert_no_selector "a", text: "Members"
    end
  end
end
