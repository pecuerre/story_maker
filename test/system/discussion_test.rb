require "application_system_test_case"

# The discussion thread in a real browser.
#
# `test/controllers/discussions_controller_test.rb` and
# `test/controllers/messages_controller_test.rb` own the authorization and the
# stored rows. What only a browser shows here is the whole journey in one piece:
# the **Discuss** control on a details page really is the form that creates the
# thread, the redirect lands on the thread, the composer really carries a CSRF
# token on the wire, and a posted message appears in the thread.
#
# Every assertion that can only be true *after* Turbo has navigated waits
# `REFRESH_WAIT`, for the reason that constant exists: a POST is a round trip and a
# render, and Capybara's default wait is shorter than a loaded machine takes. A
# toast is deliberately not asserted here — it dismisses itself after four
# seconds, so asserting it is a race — and the flash itself is covered by the
# request test.
class DiscussionTest < ApplicationSystemTestCase
  test "a writer starts a thread from a details page and replies to it" do
    sign_in_via_form(users(:user_one))
    character = characters(:character_one)

    visit universe_character_path(universe_slug: universes(:universe_one).slug, id: character)

    # No thread yet, so the control is the button that asks for one.
    within(".page-actions") do
      click_on "Discuss"
    end

    assert_selector ".discussion-composer", wait: REFRESH_WAIT
    assert_equal 1, Discussion.where(record_type: "Character", record_id: character.id).count
    assert_equal 0, character.reload.discussion.messages.count

    fill_in "discussion_message_body", with: "Is she the heir?"
    click_on "Post message"

    assert_selector ".discussion-message-body", text: "Is she the heir?", wait: REFRESH_WAIT
    assert_equal [ "Is she the heir?" ], character.reload.discussion.messages.map(&:body)

    # A thread that exists is linked to, not offered again: the control is now a
    # plain GET, because a page load is not a write.
    visit universe_character_path(universe_slug: universes(:universe_one).slug, id: character)
    within(".page-actions") do
      click_on "Discussion"
    end

    assert_selector ".discussion-message-body", text: "Is she the heir?", wait: REFRESH_WAIT
    assert_no_selector ".page-actions form[action='#{universe_discussions_path(universe_slug: universes(:universe_one).slug)}']"
  end

  test "a guest reads a thread and is offered no way to post" do
    character = characters(:character_one)
    discussion = character.find_or_create_discussion
    discussion.messages.create!(user: users(:user_one), body: "Open to everyone")

    visit universe_discussion_path(universe_slug: universes(:universe_one).slug, id: discussion)

    assert_selector ".discussion-message-body", text: "Open to everyone"
    assert_no_selector ".discussion-composer"

    visit universe_character_path(universe_slug: universes(:universe_one).slug, id: character)
    assert_no_selector ".page-actions form"
  end

  test "an empty thread states that it is empty and the first reply fills it" do
    sign_in_via_form(users(:user_one))
    location = locations(:location_one)
    discussion = location.find_or_create_discussion

    visit universe_discussion_path(universe_slug: universes(:universe_one).slug, id: discussion)

    assert_selector ".empty-state", text: /No messages yet/
    assert_selector ".discussion-message", count: 0

    fill_in "discussion_message_body", with: "Which town?"
    click_on "Post message"

    assert_selector ".discussion-message-body", text: "Which town?", wait: REFRESH_WAIT
    assert_no_selector ".empty-state"
  end
end
