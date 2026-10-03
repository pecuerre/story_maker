require "test_helper"

# Whether this browser is editing this universe right now.
#
# What only the model can be asked is whether the flag is stored per universe, per
# session, and per reader: the two ways a naive boolean-in-the-session would be
# wrong are a second universe inheriting the first one's session, and one reader's
# flag surviving a sign-out. `test/controllers/draft_editing_controller_test.rb`
# owns the request side — the control, the redirect, the authorization — and
# `test/system/draft_editing_session_test.rb` owns what an author sees in a
# browser.
class DraftEditingSessionTest < ActiveSupport::TestCase
  setup do
    @session = {}
    @user = users(:user_one)
    @universe = universes(:universe_one)
  end

  test "nobody is editing until the session says so" do
    assert_not DraftEditingSession.active?(session: @session, user: @user, universe: @universe)
  end

  test "starting claims the session and stopping releases it" do
    DraftEditingSession.start!(session: @session, user: @user, universe: @universe)

    assert DraftEditingSession.active?(session: @session, user: @user, universe: @universe)

    DraftEditingSession.stop!(session: @session, universe: @universe)

    assert_not DraftEditingSession.active?(session: @session, user: @user, universe: @universe)
  end

  test "the claim is per universe, so a second one does not inherit it" do
    other = universes(:universe_two)

    DraftEditingSession.start!(session: @session, user: @user, universe: @universe)

    assert DraftEditingSession.active?(session: @session, user: @user, universe: @universe)
    assert_not DraftEditingSession.active?(session: @session, user: @user, universe: other),
      "an editing session belongs to the universe it was started in, not to the reader or the session as a whole"

    # Stopping one universe leaves the other alone, which is the case that makes a
    # single shared flag wrong in the other direction: it would end a session the
    # reader is still working in.
    DraftEditingSession.start!(session: @session, user: @user, universe: other)
    DraftEditingSession.stop!(session: @session, universe: @universe)

    assert_not DraftEditingSession.active?(session: @session, user: @user, universe: @universe)
    assert DraftEditingSession.active?(session: @session, user: @user, universe: other)
  end

  test "stopping leaves nothing behind once the last universe is released" do
    DraftEditingSession.start!(session: @session, user: @user, universe: @universe)
    DraftEditingSession.stop!(session: @session, universe: @universe)

    assert_not @session.key?(DraftEditingSession::KEY),
      "an empty hash stored under the key would be a claim the session keeps carrying"
  end

  test "the flag is not a claim without a reader to hold the draft" do
    # A draft belongs to a person, so a guest's answer is always no. This also
    # keeps `start!`'s `Draft.open_for!` from being reachable with a nil user.
    DraftEditingSession.start!(session: @session, user: @user, universe: @universe)

    assert_not DraftEditingSession.active?(session: @session, user: nil, universe: @universe)
    assert_not DraftEditingSession.active?(session: @session, user: @user, universe: nil)
  end

  test "a session value that is not a map is no claim at all" do
    # The session is the browser's to replay, so a stored value this application
    # did not write must not raise on every page of a draft-based universe.
    @session[DraftEditingSession::KEY] = "yes"

    assert_not DraftEditingSession.active?(session: @session, user: @user, universe: @universe)

    DraftEditingSession.start!(session: @session, user: @user, universe: @universe)

    assert DraftEditingSession.active?(session: @session, user: @user, universe: @universe),
      "starting replaces the unreadable value rather than merging into it"
  end

  test "stopping a universe that was never being edited changes nothing" do
    DraftEditingSession.start!(session: @session, user: @user, universe: @universe)

    DraftEditingSession.stop!(session: @session, universe: universes(:universe_two))

    assert DraftEditingSession.active?(session: @session, user: @user, universe: @universe)
  end

  test "starting opens a draft to remember changes into, and resumes the one that is there" do
    draft = nil

    assert_difference -> { Draft.count }, 1 do
      draft = DraftEditingSession.start!(session: @session, user: @user, universe: @universe)
    end

    assert_predicate draft, :open?
    assert_equal @user, draft.user
    assert_equal @universe, draft.universe
    assert_equal draft, Draft.open_for(@user, @universe)

    # A second **Start editing** must not open a second draft. The reader's pending
    # work lives in the first one, and the partial unique index would refuse the
    # insert anyway — this says the flow looks for the open draft instead.
    assert_no_difference -> { Draft.count } do
      assert_equal draft, DraftEditingSession.start!(session: @session, user: @user, universe: @universe)
    end
  end

  test "stopping keeps the draft and every change in it" do
    draft = DraftEditingSession.start!(session: @session, user: @user, universe: @universe)
    draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Ariadne", "universe_id" => @universe.id })

    DraftEditingSession.stop!(session: @session, universe: @universe)

    assert_predicate draft.reload, :open?, "stopping an editing session is not discarding the work it held"
    assert_equal 1, draft.draft_changes.count
    assert_equal 1, Draft.pending_changes_count(@user, @universe)
  end
end
