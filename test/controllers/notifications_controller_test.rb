require "test_helper"

# One person's notifications: the page behind the bell, and the two writes that
# answer it.
#
# The request suite owns the half no browser shows — that a notification is only ever
# read as its own reader's, that a row whose universe has been destroyed still
# renders, and that nothing is announced for a decision that was refused — while
# `test/system/review_workflow_test.rb` owns the half that is: that the badge appears
# for the person who was handed something and not for the person who handed it over.
class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:user_one)
    @author = users(:user_two)
    @universe = universes(:universe_one)
  end

  # Who may read this page

  test "a guest is asked to sign in rather than shown an empty list" do
    get notifications_url

    assert_redirected_to new_session_url
  end

  test "a reader sees their own notifications and nobody else's" do
    announced(submitted_request)
    elsewhere = elsewhere_owned_universe
    announced(submitted_request(universe: elsewhere))
    sign_in_as(@owner)

    get notifications_url

    assert_response :success
    assert_select ".notification-row", count: 1
    assert_select ".notification-sentence", text: /User Two submitted a draft for review in Universe one/
    # The notice written to this reader is here and the one written to somebody else is
    # not — not hidden behind being read, simply not on this page at all.
    assert_select ".notification-sentence", text: /#{Regexp.escape(elsewhere.name)}/, count: 0
  end

  test "somebody else's notification is not this reader's page at all" do
    theirs = announced(submitted_request)
    sign_in_as(@author)

    post read_notification_url(id: theirs)

    # The scope is the whole of the authorization, so another reader's row and a row
    # that does not exist are one answer.
    assert_response :not_found
    assert_predicate theirs.reload, :unread?
  end

  # What the page prints

  test "a decision carries the reviewer's reason as its own line" do
    sign_in_as(@author)
    announced(submitted_request, decision: :rejected, notes: "The name is the old one")

    get notifications_url

    assert_response :success
    assert_select ".notification-sentence", text: /User One rejected your submission in Universe one/
    assert_select ".notification-notes", text: /The name is the old one/
    # The moment is a `<time>` of its own rather than a clause of the sentence, which is
    # scoped to the page's row because the navbar's dropdown prints one for the same
    # notification.
    assert_select ".notification-row .notification-moment time", count: 1
    assert_select ".notification-row .notification-unread-badge", text: "New"
  end

  test "a decision links at the author's own draft page" do
    sign_in_as(@author)
    notification = announced(submitted_request, decision: :approved)

    get notifications_url

    assert_response :success
    # A notification is not an authorization, and the author of a draft has no admin
    # access to a reviewer's page — so the notice written to an author has to open the
    # author's own surface, which is where the submission's status and notes live.
    assert_select "a[href=?]",
      universe_draft_path(universe_slug: @universe.slug, id: notification.payload["draft_id"])
  end

  test "a submission links at the reviewer's page rather than the author's draft" do
    sign_in_as(@owner)
    notification = announced(submitted_request)

    get notifications_url

    assert_response :success
    assert_select "a[href=?]",
      universe_review_request_path(universe_slug: @universe.slug, id: notification.payload["review_request_id"])
  end

  test "a notification about a universe that no longer exists still renders" do
    sign_in_as(@author)
    announced(submitted_request, decision: :approved)
    @universe.destroy!

    get notifications_url

    # Nothing in the row is resolved to print it, which is the whole reason the payload
    # is a sentence. The link inside it will 404, and that is the accepted price.
    assert_response :success
    assert_select ".notification-sentence", text: /User One approved your submission in Universe one/
  end

  test "a row with nothing to link at still prints its sentence" do
    sign_in_as(@author)
    # Nothing this application writes, and the column is nullable. One row that cannot
    # be linked at must not take the bell's whole page down with it.
    Notification.create!(user: @author, kind: "review_approved")

    get notifications_url

    assert_response :success
    assert_select ".notification-row .notification-sentence", text: /Someone approved your submission/
    assert_select ".notification-row a", count: 0
    assert_select ".notification-menu .dropdown-item-text", minimum: 1
  end

  test "a reader with nothing is told so rather than shown an empty list" do
    sign_in_as(@author)

    get notifications_url

    assert_response :success
    assert_select ".notification-row", count: 0
    assert_select ".empty-title", text: I18n.t("notifications.empty_title")
  end

  # Marking read

  test "marking one read is the reader's own act and leaves the rest alone" do
    first = announced(submitted_request, decision: :approved)
    second = announced(submitted_request(universe: reviewable_universe), decision: :rejected, notes: "Again")
    sign_in_as(@author)

    post read_notification_url(id: first)

    assert_redirected_to notifications_url
    assert_predicate first.reload, :read?
    assert_predicate second.reload, :unread?
  end

  test "marking all read touches only this reader's unread rows" do
    mine = announced(submitted_request, decision: :approved)
    already_read = announced(submitted_request(universe: reviewable_universe), decision: :rejected)
    already_read.mark_read!
    somebody_elses = announced(submitted_request(universe: elsewhere_owned_universe))
    sign_in_as(@author)

    post read_all_notifications_url

    assert_redirected_to notifications_url
    assert_predicate mine.reload, :read?
    # A row somebody else owns is not in the scope at all, so "mark all" cannot reach it.
    assert_not_predicate somebody_elses.reload, :read?
    # And a row that was already read is not what the count was about.
    assert_equal 1, @author.notifications.where(read: true).count
  end

  # The bell

  test "the navbar's badge counts what is unread and disappears when nothing is" do
    notification = announced(submitted_request, decision: :approved)
    sign_in_as(@author)

    get notifications_url

    assert_select ".notification-badge", text: "1"
    assert_select ".notification-menu .notification-item", count: 1

    notification.mark_read!

    get notifications_url

    # The bell itself stays: a reader who has read everything still has a list, and
    # hiding the bell would hide the way into it.
    assert_select ".notification-badge", count: 0
    assert_select ".notification-menu", count: 1
  end

  test "the bell prints at most the panel's limit of entries" do
    sign_in_as(@author)
    (Notification::PANEL_LIMIT + 2).times do |index|
      Notification.create!(user: @author, kind: "review_submitted",
        payload: { "universe_slug" => @universe.slug, "universe_name" => @universe.name,
                   "draft_id" => index, "review_request_id" => index })
    end

    get notifications_url

    # The dropdown is rendered on every page of the application, so the rest of the
    # list is counted on the page rather than printed here.
    assert_select ".notification-menu .notification-item", count: Notification::PANEL_LIMIT
    assert_select ".notification-row", count: Notification::PANEL_LIMIT + 2
  end

  test "a guest is offered no bell, because there is nothing addressed to a guest" do
    get root_url

    assert_response :success
    assert_select ".notification-menu", count: 0
  end

  # Where the notices come from

  test "submitting a draft tells the reviewers and approving it tells the author" do
    request_record = submitted_request
    sign_in_as(@owner)

    # One row for the submission, written by `Draft#submit!` inside its own
    # transaction: the author pressed the control and is not told, the reviewer is.
    assert_equal [ "review_submitted" ], @owner.notifications.pluck(:kind)
    assert_empty @author.notifications

    post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record)
    assert_response :see_other

    assert_equal [ "review_approved" ], @author.notifications.pluck(:kind)
    # The reviewer is not told their own decision landed.
    assert_equal [ "review_submitted" ], @owner.notifications.pluck(:kind)
  end

  test "a rejection tells the author with the reason" do
    request_record = submitted_request
    sign_in_as(@owner)

    post reject_universe_review_request_url(universe_slug: @universe.slug, id: request_record),
      params: { review_request: { review_notes: "The name is the old one" } }
    assert_response :see_other

    notification = @author.notifications.sole
    assert_equal "review_rejected", notification.kind
    assert_equal "The name is the old one", notification.payload["review_notes"]
  end

  test "a refused rejection tells nobody" do
    request_record = submitted_request
    sign_in_as(@owner)

    post reject_universe_review_request_url(universe_slug: @universe.slug, id: request_record),
      params: { review_request: { review_notes: "" } }

    assert_response :unprocessable_content
    assert_empty @author.notifications
    assert_predicate request_record.reload, :pending?
  end

  test "an approval stopped by a conflict tells nobody" do
    character = characters(:character_one)
    draft = Draft.create!(user: @author, universe: @universe)
    draft.draft_changes.create!(action: "update", record_type: "Character", record_id: character.id,
      base_version: DraftChange.capture_base_version(character), payload: { "name" => "Renamed by a submission" })
    request_record = draft.submit!
    character.update!(name: "Somebody else got here first")
    sign_in_as(@owner)

    post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record)

    # The run was refused, so the decision was never taken and there is nothing to
    # announce: a notice about an approval that did not happen is worse than silence.
    assert_response :unprocessable_content
    assert_empty @author.notifications
    assert_predicate request_record.reload, :pending?
  end

  test "an approval decided twice is refused rather than announced twice" do
    request_record = submitted_request
    sign_in_as(@owner)

    post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record)
    post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record)

    assert_response :see_other
    assert_equal 1, @author.notifications.where(kind: "review_approved").count
  end

  private
    # One submission with a single remembered create, built the way the application
    # builds one, so the notice under test is the one a real handover writes. One open
    # draft per author per universe is the database's rule, so a test needing a second
    # handover from the same author passes a second universe.
    def submitted_request(universe: @universe, author: @author)
      draft = Draft.create!(user: author, universe: universe)
      draft.draft_changes.create!(action: "create", record_type: "Character", record_id: nil,
        base_version: nil, payload: { "name" => "A remembered character" })

      draft.submit!
    end

    # A universe whose owner is somebody else, so a submission in it is announced to a
    # third person rather than to either of the two the fixtures provide. It has to be
    # private, because a public universe grants every signed-in reader `write` and the
    # membership row would then be saying nothing.
    def elsewhere_owned_universe
      @elsewhere_owned_universe ||= Universe.create!(
        owner: User.create!(name: "User Three", email_address: "three@example.com", password: "password"),
        name: "Elsewhere", slug: "elsewhere", private: true
      )
    end

    # A second universe `author` can submit in and this reviewer can still decide,
    # because one open draft per author per universe is a database rule.
    def reviewable_universe
      @reviewable_universe ||= begin
        universe = Universe.create!(owner: @owner, name: "Second review", slug: "second-review", private: true)
        UniverseMembership.create!(user: @author, universe: universe, access_level: "write")
        universe
      end
    end

    # A submission, and the notice its own transition wrote. `decision:` takes it to an
    # approval or a rejection through the same call a reviewer would make, so the notice
    # under test is the one a real decision writes rather than one this test assembled;
    # the decisions themselves are covered by `review_requests_controller_test.rb`.
    def announced(request_record, decision: nil, notes: nil)
      return @owner.notifications.order(:id).last if decision.nil?

      if decision == :approved
        request_record.update!(status: "approved", reviewed_by: @owner, review_notes: notes.presence)
        Notification.review_decided!(request_record)
      else
        request_record.reject!(@owner, notes: notes)
      end

      @author.notifications.order(:id).last
    end
end
