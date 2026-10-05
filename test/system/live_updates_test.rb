require "application_system_test_case"

# Real-time updates in a real browser.
#
# `test/services/live_updates_test.rb` owns which stream an event goes to and what
# the broadcast contains; `test/javascript/live_update_controller_test.js` owns the
# rule about when a refresh is applied. What is left is the part neither can see:
# that **a subscription is actually answered and the page changes without anybody
# reloading it**. That needs a real websocket, a real Chrome, and two signed-in
# readers, which is why it is a system test and why `config/cable.yml` uses the
# `async` adapter in the test environment rather than `test`.
#
# The two readers are two browser sessions in one process. The publisher is the
# **model**, not a second browser, and that is deliberate: driving the second
# browser would prove the request path twice over while making every case slower and
# more flaky, and the request suite already owns what a POST does. What has to be
# real here is the delivery.
class LiveUpdatesTest < ApplicationSystemTestCase
  setup do
    @universe = universes(:universe_one)
    @author = users(:user_one)
    @reader = users(:user_two)
    @universe.update!(collaboration_mode: "wikipedia")
  end

  # The headline case: a reader is looking at the Characters list, somebody else
  # applies a draft that creates a Character, and the list grows under them without
  # a navigation. Before slice 6.2 this was the "somebody edited this universe and
  # your page does not know" case, which is exactly the defect the pending badges in
  # the lists made visible and could not answer.
  #
  # The write is made in-process rather than in a second browser: it is the same
  # model call the reviewer's **Approve** makes, and what has to be real here is the
  # delivery to a page that did not ask for it. Driving the second reader through
  # the UI would prove the request path again — which
  # `test/system/draft_workflow_test.rb` already does — and would give this file a
  # second browser whose failures would say nothing about the websocket.
  test "a draft applied by another reader refreshes this reader's list without a reload" do
    sign_in_via_form(@reader)
    visit universe_characters_path(universe_slug: @universe.slug)

    listed = Character.where(universe: @universe).count
    assert_selector ".entity-row", count: listed
    assert_no_selector ".entity-title", text: "Applied while you were reading"

    apply_a_draft_creating("Applied while you were reading", author: @author)

    assert_selector ".entity-title", text: "Applied while you were reading", wait: REFRESH_WAIT
    assert_selector ".entity-row", count: listed + 1
    assert_equal universe_characters_path(universe_slug: @universe.slug), current_path,
      "the page was re-read in place rather than navigated to"
  end

  # The thread's own stream, and the case the layout's universe subscription cannot
  # cover on its own: the reader is on the thread, and the message arrives there.
  test "a reply posted by another reader appears on the thread they are reading" do
    character = characters(:character_one)
    discussion = character.find_or_create_discussion
    discussion.messages.create!(user: @author, body: "Is she the heir?")

    sign_in_via_form(@reader)
    visit universe_discussion_path(universe_slug: @universe.slug, id: discussion)
    assert_selector ".discussion-message-body", text: "Is she the heir?"

    discussion.messages.create!(user: @author, body: "She is, and there is a claim to prove it.")

    assert_selector ".discussion-message-body", text: "She is, and there is a claim to prove it.", wait: REFRESH_WAIT
    assert_selector ".discussion-message", count: 2
  end

  # The unsent-work rule, which is the whole reason the client controller exists. A
  # reply arrives while the reader is halfway through writing one, and the reader
  # loses nothing: the page does not refresh, the notice says so, and the composer
  # keeps exactly what was typed.
  test "a reply is held while this reader is writing one" do
    character = characters(:character_one)
    discussion = character.find_or_create_discussion
    discussion.messages.create!(user: @reader, body: "Is she the heir?")

    sign_in_via_form(@author)
    visit universe_discussion_path(universe_slug: @universe.slug, id: discussion)

    fill_in "discussion_message_body", with: "I think the claim is forged"
    discussion.messages.create!(user: @reader, body: "There is a second claimant.")

    assert_selector ".live-update-notice--visible", text: /changed this universe/, wait: REFRESH_WAIT
    # The composer keeps exactly what was typed, which is the reason the refresh was
    # held at all.
    assert_field "discussion_message_body", with: "I think the claim is forged"
    # The page did not refresh, so the new message is not on it yet: that absence is
    # the same fact as the notice being visible.
    assert_selector ".discussion-message", count: 1

    # The notice's own control is the way the reader takes the update when they have
    # finished writing.
    click_on "Reload"

    assert_selector ".discussion-message-body", text: "There is a second claimant.", wait: REFRESH_WAIT
    assert_selector ".discussion-message", count: 2
  end

  # The bell is the third stream, and it is the one a reader is most often away
  # from: the notification is written while this reader is on a page in a different
  # universe, and the figure they were promised — uncached, because nothing could
  # expire it — is simply there.
  test "a notification for this reader appears in the bell while they are reading" do
    # The universe's owner, because a submission is announced to its administrators
    # (`conventions.md#notifications`), and this universe's owner is its only one.
    sign_in_via_form(@author)

    visit universe_character_path(universe_slug: @universe.slug, id: characters(:character_one))
    assert_no_selector ".notification-badge"

    draft_remembering("Waiting for a decision", author: @reader).submit!

    assert_selector ".notification-badge", text: "1", wait: REFRESH_WAIT
  end

  # A guest has no session, so `ApplicationCable::Connection` refuses the websocket.
  # The layout therefore renders no subscription at all rather than rendering one
  # that would be rejected on arrival — which is also why a guest's page cannot be
  # made to answer one.
  test "a guest is offered no subscription and no notice" do
    character = characters(:character_one)

    visit universe_character_path(universe_slug: @universe.slug, id: character)

    assert_no_selector "turbo-cable-stream-source", visible: :all
    assert_no_selector ".live-update-notice"
    assert_selector "h1", text: character.name
  end

  # The signed stream name is the authorization. A reader in one universe cannot be
  # handed a subscription to another's stream by anything this application renders,
  # and the verification on the channel side refuses one that is not signed at all.
  test "a page inside a universe subscribes to its own universe and its own reader, and nothing else" do
    sign_in_via_form(@reader)
    visit universe_character_path(universe_slug: @universe.slug, id: characters(:character_one))

    # `visible: :all` because a stream source is a custom element with no box of its
    # own: it is in the DOM and connected, which is the whole of what it is.
    assert_selector "turbo-cable-stream-source", count: 2, visible: :all
    assert_equal signed(LiveUpdates.reader_stream(@reader)), subscribed_stream_names.first
    assert_equal signed(LiveUpdates.universe_stream(@universe)), subscribed_stream_names.second
  end

  private

    # A draft with one remembered create, applied the way the applier applies it.
    # Calling the service rather than pressing the button keeps this file about
    # delivery; the button's own journey is `draft_workflow_test.rb`.
    def apply_a_draft_creating(name, author: @author)
      DraftApplier.new(draft_remembering(name, author: author)).apply
    end

    def draft_remembering(name, author: @author)
      Draft.open_for!(author, @universe).tap do |draft|
        draft.draft_changes.create!(
          action: "create",
          record_type: "Character",
          payload: { "name" => name, "universe_id" => @universe.id }
        )
      end
    end

    def signed(streamables)
      Turbo::StreamsChannel.signed_stream_name(streamables)
    end

    def subscribed_stream_names
      all("turbo-cable-stream-source", visible: :all).map { |element| element["signed-stream-name"] }
    end
end
