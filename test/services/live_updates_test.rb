require "test_helper"

# What this application publishes over the websocket, and to which stream.
#
# `test/system/live_updates_test.rb` proves the browser end: that a subscription is
# answered and another reader's page changes without being reloaded. What only a
# Ruby test can say is the half a browser cannot show — **which stream an event goes
# to** — because a wrong stream looks exactly like a working one right up until two
# readers are standing in different universes.
#
# **It subscribes rather than asserting on Turbo's tag builder.** The
# `ActionCable::TestHelper` assertions (`assert_broadcasts`) need the `test` pubsub
# adapter, and the test environment uses `async` because the system suite has to
# receive real deliveries (see `config/cable.yml`). Subscribing directly tests the
# thing this application decided — the stream name, and the event's marker — and
# leaves Turbo's own tag building to Turbo, which is the same division
# `LiveUpdates` is written on.
#
# **`async` delivers on Action Cable's event loop**, so a broadcast has not arrived
# by the time the next line runs. Every case therefore ends with `settled`, which
# publishes a sentinel to each subscription it is asserting about and waits for it.
# A stream delivers in order, so once the sentinel has landed, anything that was
# going to arrive on that stream has arrived — which is what makes `assert_empty`
# here a real assertion rather than a race that happens to pass on an idle machine.
#
# **The broadcast carries a refresh and nothing else.** That is asserted rather than
# assumed, because it is the design's whole weight: a broadcast that carried content
# would be rendered without the receiving reader's locale and without their access
# to the universe it is about, and no assertion about a stream name would catch that.
class LiveUpdatesTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_one)
    @subscriptions = []
  end

  teardown do
    @subscriptions.reverse_each(&:close)
  end

  # An applied draft, a thread's reply, and a notification each reach one stream and
  # no other. Asserting the negative is the point: a universe broadcast that also
  # went to every reader would refresh the whole application's signed-in population.
  # Each event is published by the write that caused it, so nothing here calls
  # `LiveUpdates` directly: applying a draft, posting a reply, and writing a
  # notification announce themselves, and a case that had to invoke the broadcaster
  # by hand would pass even if the commit callbacks were gone.
  test "each event reaches its own stream and no other" do
    discussion = character_discussion
    universe = subscribe_to(LiveUpdates.universe_stream(@universe))
    thread = subscribe_to(LiveUpdates.discussion_stream(discussion))
    reader = subscribe_to(LiveUpdates.reader_stream(@user))
    bystander = subscribe_to(LiveUpdates.reader_stream(users(:user_two)))

    applied_draft
    posted_reply(discussion)
    notification_for(@user)
    settled

    assert_equal 1, universe.delivered.size, "an applied draft is announced once, to its universe"
    assert_equal 1, thread.delivered.size, "a reply is announced to its thread"
    assert_equal 1, reader.delivered.size, "a notification is announced to its reader"
    assert_empty bystander.delivered, "a notification is not announced to anybody else"
  end

  test "a reply is not announced to the universe or to a reader who was not told" do
    discussion = character_discussion
    universe = subscribe_to(LiveUpdates.universe_stream(@universe))
    bystander = subscribe_to(LiveUpdates.reader_stream(users(:user_two)))

    posted_reply(discussion)
    settled

    assert_empty universe.delivered,
      "a reply is a conversation between the people who posted in it, not a universe-wide event"
    assert_empty bystander.delivered,
      "a reader `Notification` did not tell is a reader the broadcast does not tell either"
  end

  # The three streams are three audiences, so they must not be able to name each
  # other. A universe id and a reader id are both integers, so a stream name built
  # from the wrong one would deliver an author's applied draft to whoever holds that
  # id — which is why the middle segment is named rather than implied.
  test "the three audiences cannot name each other's stream" do
    assert_equal "collaboration:universe:#{@universe.id}", stream_name(LiveUpdates.universe_stream(@universe))
    assert_equal "collaboration:reader:#{@user.id}", stream_name(LiveUpdates.reader_stream(@user))

    # Ids are fixture-generated integers, so an id shared between a universe and a
    # discussion cannot be arranged here. The named middle segment is what rules it
    # out, and the readable stream name says so directly.
    discussion = character_discussion

    assert_equal "collaboration:discussion:#{discussion.id}", stream_name(LiveUpdates.discussion_stream(discussion))

    names = [ LiveUpdates.universe_stream(@universe), LiveUpdates.reader_stream(@user),
      LiveUpdates.discussion_stream(discussion) ].map { |streamables| stream_name(streamables) }

    assert_equal names.uniq.size, names.size, "a universe, a reader, and a discussion are three streams, not two"
  end

  test "no stream is named without the thing it is about" do
    assert_nil LiveUpdates.universe_stream(nil)
    assert_nil LiveUpdates.discussion_stream(nil)
    assert_nil LiveUpdates.reader_stream(nil)
  end

  # The refresh is a signal, so what arrives must carry no rendered content: no
  # name, no sentence, no id. It is rendered outside every request that would have
  # resolved the reader's language and their access to the universe.
  test "what a reader receives is a refresh with nothing rendered into it" do
    character = characters(:character_one)
    universe = subscribe_to(LiveUpdates.universe_stream(@universe))

    applied_draft
    settled

    message = universe.delivered.sole
    assert_includes message, 'action="refresh"'
    assert_includes message, 'data-live-update="draft_applied"'
    assert_no_match(/<template/, message, "a broadcast carrying content would be rendered without its reader")
    assert_no_match(/#{Regexp.escape(character.name)}/, message)
  end

  # `request-id` keeps the person who pressed the button out of their own refresh:
  # Turbo drops a refresh whose request id the page has just made itself. Without
  # it, applying a draft would reload the page of the person who applied it,
  # underneath the navigation they are already doing.
  test "a broadcast carries the request id of the request that caused it" do
    universe = subscribe_to(LiveUpdates.universe_stream(@universe))
    request_id = SecureRandom.uuid

    with_turbo_request_id(request_id) { applied_draft }
    settled

    assert_includes universe.delivered.sole, %(request-id="#{request_id}")
  end

  # The commit callbacks are the other half of the decision. A refresh published
  # inside the applier's transaction would invite every reader to re-read a universe
  # that has not been written yet, so the announcement waits for the outermost commit
  # — which is also what makes a reviewer's approval correct, since that write is
  # wrapped in the decision's own transaction above the applier's.
  test "an apply announces itself only once its transaction has committed" do
    draft = draft_with_change
    universe = subscribe_to(LiveUpdates.universe_stream(@universe))

    ApplicationRecord.transaction do
      DraftApplier.new(draft).apply

      assert_empty universe.delivered, "nothing is announced while the run is still open"
    end
    settled

    assert_equal 1, universe.delivered.size
  end

  test "a rolled back apply announces nothing" do
    draft = draft_with_change
    universe = subscribe_to(LiveUpdates.universe_stream(@universe))

    ApplicationRecord.transaction do
      DraftApplier.new(draft).apply
      raise ActiveRecord::Rollback
    end
    settled

    assert_empty universe.delivered, "a rolled back apply wrote nothing, so there is nothing to announce"
  end

  # A refused reply writes neither the message nor the announcement: `post!` answers
  # false for an empty composer rather than raising, and a thread refreshed onto a
  # message that was refused is worse than a thread that did not move.
  test "a refused reply announces nothing" do
    discussion = character_discussion
    thread = subscribe_to(LiveUpdates.discussion_stream(discussion))

    assert_not discussion.messages.new(user: @user, body: "").post!
    settled

    assert_empty thread.delivered
  end

  test "marking a notification read announces nothing again" do
    reader = subscribe_to(LiveUpdates.reader_stream(@user))
    notification = notification_for(@user)
    settled

    notification.mark_read!
    settled

    assert_equal 1, reader.delivered.size,
      "marking a row read is the reader's own act on a page they are already looking at"
  end

  # A reviewer's approval runs the applier inside the decision's own transaction.
  # If the announcement were published by the applier as it ran, the universe would
  # be announced one commit too early — before the request that authorized the write
  # is itself committed.
  test "an approval announces the universe only after the decision commits" do
    universe = subscribe_to(LiveUpdates.universe_stream(@universe))
    draft = draft_with_change
    request = ReviewRequest.create!(draft: draft, universe: @universe, submitted_by: @user)

    ApplicationRecord.transaction do
      DraftApplier.new(draft).apply
      request.update!(status: "approved", reviewed_by: users(:user_two))

      assert_empty universe.delivered, "neither the run nor the decision is committed yet"
    end
    settled

    assert_equal 1, universe.delivered.size, "the run and the decision announce themselves once, together"
  end

  private

    # One browser tab's worth of a subscription, holding what the stream delivered.
    #
    # `delivered` is the messages that are not the sentinel `settled` publishes to
    # close the ordering gap, so a case can assert on what an event published rather
    # than on what the test itself wrote.
    class Subscription
      SENTINEL = "<turbo-stream data-live-update=\"sentinel\" action=\"remove\"></turbo-stream>".freeze

      attr_reader :messages

      def initialize(channel)
        @channel = channel
        @messages = []
        @confirmed = Queue.new
      end

      attr_reader :channel

      # The handler is one object held for the subscription's life, because
      # `unsubscribe` removes by identity: a second `method(:call)` would be a
      # different object and the subscription would outlive the case.
      #
      # It decodes what arrives, because this subscribes to the **pubsub** rather
      # than to a channel: `ActionCable.server.broadcast` encodes with
      # `ActiveSupport::JSON`, and a channel's own stream handler is what decodes it
      # again. Decoding here is what a browser tab receives, and skipping it would
      # make every assertion here read a JSON string rather than the tag.
      def handler
        @handler ||= ->(message) { @messages << ActiveSupport::JSON.decode(message) }
      end

      def confirmed
        @confirmed.pop
      end

      def confirm
        @confirmed << true
      end

      def delivered
        messages.reject { |message| message == SENTINEL }
      end

      # How long a case waits for a delivery the `async` adapter has already been
      # handed. It posts onto Action Cable's event loop, so a broadcast is not
      # delivered by the time the line after it returns; a fixed sleep would be
      # either too short on a loaded machine or wasted on an idle one.
      def wait_for_sentinel(timeout: 5)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

        sleep 0.01 until messages.include?(SENTINEL) ||
          (Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline)

        raise Minitest::Assertion, "the #{@channel} subscription never received the sentinel, so nothing " \
          "published before it can be asserted on" unless messages.include?(SENTINEL)
      end

      def close
        ActionCable.server.pubsub.unsubscribe(channel, handler)
      end
    end

    def subscribe_to(streamables)
      subscription = Subscription.new(stream_name(streamables))
      ActionCable.server.pubsub.subscribe(subscription.channel, subscription.handler, subscription.method(:confirm))
      subscription.confirmed
      @subscriptions << subscription
      subscription
    end

    # Wait until every subscription has seen the sentinel. A stream delivers in
    # order, so a subscription that has received the sentinel has also received
    # everything published before it, which is what makes the empty assertions in
    # this file statements about the application rather than about timing.
    def settled
      # Published through `ActionCable.server` rather than through `pubsub` directly,
      # so it is encoded exactly as the events under test are. A sentinel that
      # arrived unencoded would be decoded by nothing and never compared equal.
      @subscriptions.each { |subscription| ActionCable.server.broadcast(subscription.channel, Subscription::SENTINEL) }
      @subscriptions.each(&:wait_for_sentinel)
    end

    # The name `Turbo::StreamsChannel` subscribes to, which is the unsigned name the
    # signed one verifies back to — the same round trip a browser's subscription
    # makes, so a stream name this service builds and one its own views build cannot
    # disagree without failing here.
    def stream_name(streamables)
      Turbo::StreamsChannel.verified_stream_name(Turbo::StreamsChannel.signed_stream_name(streamables))
    end

    def with_turbo_request_id(request_id)
      previous = Turbo.current_request_id
      Turbo.current_request_id = request_id
      yield
    ensure
      Turbo.current_request_id = previous
    end

    def character_discussion
      characters(:character_one).find_or_create_discussion
    end

    def posted_reply(discussion, body: "Look again")
      discussion.messages.create!(user: users(:user_two), body: body)
    end

    def notification_for(user)
      Notification.create!(user: user, kind: "review_submitted",
        payload: { "universe_slug" => @universe.slug, "review_request_id" => 1 })
    end

    def applied_draft
      draft = draft_with_change
      DraftApplier.new(draft).apply
      draft
    end

    def draft_with_change(name: "Applied in the background")
      Draft.create!(user: @user, universe: @universe).tap do |draft|
        draft.draft_changes.create!(
          action: "create",
          record_type: "Character",
          payload: { "name" => name, "universe_id" => @universe.id }
        )
      end
    end
end
