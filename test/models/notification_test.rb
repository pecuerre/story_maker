require "test_helper"

# One thing that happened to one person.
#
# The model suite owns the three questions the rest of the notification feature reads
# its answers from: **who is told** about a submission and about a decision, **what is
# stored** so the bell can print a row without resolving anything, and **what happens
# when the thing a notification is about is destroyed**. The last of those is the reason
# the payload is a sentence rather than a pointer, and it is easy to break by adding a
# foreign key, so it is asserted here rather than described in a comment.
class NotificationTest < ActiveSupport::TestCase
  setup do
    @owner = users(:user_one)
    @author = users(:user_two)
    @universe = universes(:universe_one)
  end

  # What a row may be

  test "a kind is required and has to be one this application can read" do
    assert_not Notification.new(user: @owner, kind: nil).valid?
    assert_not Notification.new(user: @owner, kind: "wibble").valid?
    assert Notification.new(user: @owner, kind: "review_submitted").valid?
  end

  test "the kinds are validated against the stored list" do
    # The list the badge and the sentence frame are keyed by, so a kind with no
    # sentence behind it would be a row nothing can print.
    assert_equal %w[review_submitted review_approved review_rejected], Notification::KINDS
  end

  test "a notification belongs to one reader" do
    assert_not Notification.new(kind: "review_submitted").valid?
  end

  # A submission

  test "a submission is announced to the universe's administrators" do
    notification = Notification.review_submitted!(submitted_request).sole

    assert_equal @owner, notification.user
    assert_equal "review_submitted", notification.kind
  end

  test "a submission is announced to an admin member as well as to the owner" do
    admin = User.create!(name: "User Three", email_address: "three@example.com", password: "password")
    UniverseMembership.create!(user: admin, universe: @universe, access_level: "admin")

    assert_equal [ @owner, admin ].sort_by(&:id), Notification.review_submitted!(submitted_request).map(&:user).sort_by(&:id)
  end

  test "a submission is not announced to a member who may only write" do
    contributor = User.create!(name: "User Four", email_address: "four@example.com", password: "password")
    UniverseMembership.create!(user: contributor, universe: @universe, access_level: "write")

    # `write` is not the queue's access level, so somebody who may not open the queue
    # is somebody who must not be told a submission is in it.
    assert_not_includes Notification.review_submitted!(submitted_request).map(&:user), contributor
  end

  test "a submission is not announced to the author, who is holding the draft" do
    # The author pressed the control that caused this and the page they land on already
    # says it, so a row would be the same news twice. An author who is also the
    # universe's only administrator therefore gets nothing — which is correct: there is
    # nobody else who could review the draft.
    owned = Universe.create!(owner: @author, name: "Own universe", slug: "own-universe", private: true)

    assert_empty Notification.review_submitted!(submitted_request(universe: owned))
  end

  test "a submission is not announced in another universe's administrators" do
    elsewhere = Universe.create!(owner: User.create!(name: "User Five", email_address: "five@example.com",
      password: "password"), name: "Elsewhere", slug: "elsewhere", private: true)

    notified = Notification.review_submitted!(submitted_request(universe: elsewhere))

    assert_equal [ elsewhere.owner ], notified.map(&:user)
    assert_not_includes notified.map(&:user), @owner
  end

  # A decision

  test "an approval is announced to the author and carries no note when there was none" do
    request_record = submitted_request
    request_record.update!(status: "approved", reviewed_by: @owner)

    notification = Notification.review_decided!(request_record).sole

    assert_equal @author, notification.user
    assert_equal "review_approved", notification.kind
    assert_nil notification.payload["review_notes"]
  end

  test "a rejection is announced to the author with the reason it was refused" do
    request_record = submitted_request
    request_record.update!(status: "rejected", reviewed_by: @owner, review_notes: "The name is the old one")

    notification = Notification.review_decided!(request_record).sole

    assert_equal "review_rejected", notification.kind
    # The notes exist to tell the author why, so a notice that said only "rejected"
    # would send them back to the drafts page to find out what to change.
    assert_equal "The name is the old one", notification.payload["review_notes"]
  end

  test "an empty note is stored as nothing rather than as a blank box" do
    request_record = submitted_request
    request_record.update!(status: "approved", reviewed_by: @owner, review_notes: "")

    assert_nil Notification.review_decided!(request_record).sole.payload["review_notes"]
  end

  test "a withdrawal is announced to nobody" do
    request_record = submitted_request
    request_record.update!(status: "withdrawn")

    assert_raises ArgumentError do
      Notification.review_decided!(request_record)
    end
  end

  # What is stored

  test "the payload says enough to print a row and to link at it" do
    request_record = submitted_request
    request_record.update!(status: "rejected", reviewed_by: @owner, review_notes: "Rename again")

    payload = Notification.review_decided!(request_record).sole.payload

    # The slug and the name are copied because the universe's link and its title both
    # have to keep working after the submission it names is gone.
    assert_equal @universe.slug, payload["universe_slug"]
    assert_equal @universe.name, payload["universe_name"]
    assert_equal request_record.draft_id, payload["draft_id"]
    assert_equal request_record.id, payload["review_request_id"]
    assert_equal @owner.name, payload["actor_name"]
  end

  test "a notification outlives the universe it is about" do
    request_record = submitted_request
    request_record.update!(status: "approved", reviewed_by: @owner)
    notification = Notification.review_decided!(request_record).sole

    # The submission is destroyed with its draft and with its universe, so a row that
    # resolved any of those to print itself would raise. This is the whole reason the
    # payload is a sentence.
    @universe.destroy!

    assert_predicate notification.reload, :persisted?
    assert_equal @universe.name, notification.payload["universe_name"]
    assert_empty @universe.review_requests
  end

  # Reading them

  test "the newest come first, with the id breaking a tie inside one clock tick" do
    older = Notification.create!(user: @owner, kind: "review_submitted", created_at: 2.days.ago)
    same_tick = 1.day.ago
    first = Notification.create!(user: @owner, kind: "review_submitted", created_at: same_tick)
    second = Notification.create!(user: @owner, kind: "review_approved", created_at: same_tick)

    assert_equal [ second, first, older ], @owner.notifications.newest_first.to_a
  end

  test "unread asks the stored flag rather than a second column" do
    read_row = Notification.create!(user: @owner, kind: "review_submitted", read: true)
    unread_row = Notification.create!(user: @owner, kind: "review_approved")

    assert_equal [ unread_row ], @owner.notifications.unread.to_a
    assert_predicate read_row, :read?
    assert_predicate unread_row, :unread?
  end

  test "marking read is idempotent and leaves the rest of the list alone" do
    mine = Notification.create!(user: @owner, kind: "review_submitted")
    somebody_elses = Notification.create!(user: @author, kind: "review_submitted")

    assert mine.mark_read!
    assert mine.mark_read!

    assert_predicate mine.reload, :read?
    assert_predicate somebody_elses.reload, :unread?
  end

  private
    # One submission of a draft that remembers a single create, by `author` in
    # `universe`. Built the way the application builds one — `Draft#submit!` — so the
    # notice under test is the one a real handover writes.
    def submitted_request(universe: @universe, author: @author)
      draft = Draft.create!(user: author, universe: universe)
      draft.draft_changes.create!(action: "create", record_type: "Character", record_id: nil,
        base_version: nil, payload: { "name" => "A remembered character" })

      draft.submit!
    end
end
