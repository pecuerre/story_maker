require "test_helper"

# The reviewer's queue, in the right sidebar.
#
# The queue itself, its rows, and the two decisions are `review_requests_controller_test.rb`'s;
# what only this file owns is the way in from the workspace, and four things about it are
# worth pinning here and nowhere else:
#
# - **it is the owner's and the admins'**, because `UniverseAuthorization` asks for `admin`
#   across the whole `review_requests` controller — the same line memberships use — so the
#   entry has to agree with the route it opens rather than with a reader's own access;
# - **it is not gated on the collaboration mode**, because a submission made while the
#   universe was in `github` mode is still a submission somebody has to decide, and the
#   queue's own pages stay reachable in every mode for the same reason;
# - **its figure counts what is waiting rather than what the queue holds**, so a decided or
#   withdrawn submission lowers nothing that a reviewer is being asked to do;
# - **the figure is uncached**, so it cannot contradict the decision the reviewer has just
#   taken on the page it redirects to — the trade `MenuCountCache` would make differently
#   for the left sidebar's counts.
class ReviewRequestsSidebarTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @universe.update!(collaboration_mode: "github")
    @owner = users(:user_one)
    @author = users(:user_two)
    sign_in_as(@owner)
  end

  test "the owner is given the queue and how much of it is waiting" do
    review_request
    review_request(by: third_author)

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".sidebar-section--tools a.sidebar-link[href=?]",
      universe_review_requests_path(universe_slug: @universe.slug), count: 1 do
      assert_select ".sidebar-link-label", text: I18n.t("sidebar.tools.review_requests")
    end
    assert_select "a.sidebar-link[href=?] .sidebar-count", universe_review_requests_path(universe_slug: @universe.slug),
      text: "2"
  end

  test "an admin who is not the owner is given it too" do
    administered = Universe.create!(owner: @owner, name: "Administered", slug: "administered", private: true)
    UniverseMembership.create!(user: users(:user_two), universe: administered, access_level: "admin")
    sign_out
    sign_in_as(users(:user_two))

    get universe_characters_path(universe_slug: administered.slug)

    assert_response :success
    assert_select "a.sidebar-link[href=?]", universe_review_requests_path(universe_slug: administered.slug), count: 1
  end

  test "a plain writer is not" do
    contributed = Universe.create!(owner: @author, name: "Contributed", slug: "contributed", private: true)
    UniverseMembership.create!(user: @owner, universe: contributed, access_level: "write")

    get universe_characters_path(universe_slug: contributed.slug)

    assert_response :success
    assert_select "a.sidebar-link[href=?]", universe_review_requests_path(universe_slug: contributed.slug), count: 0
  end

  test "a guest is not" do
    review_request
    sign_out

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select "a.sidebar-link[href=?]", universe_review_requests_path(universe_slug: @universe.slug), count: 0
  end

  test "the entry stays once everything has been decided, and says zero" do
    decided = review_request
    decided.update!(status: "approved", reviewed_by: @owner)
    withdrawn = review_request(by: third_author)
    withdrawn.withdraw!

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    # The queue is where a reviewer reads who let a change through, so the entry is not
    # a control that appears and disappears with a count.
    assert_select "a.sidebar-link[href=?] .sidebar-count", universe_review_requests_path(universe_slug: @universe.slug),
      text: "0"
  end

  test "another universe's waiting submissions are not counted here" do
    elsewhere = Universe.create!(owner: @owner, name: "Elsewhere", slug: "elsewhere")
    review_request(universe: elsewhere)
    review_request

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select "a.sidebar-link[href=?] .sidebar-count", universe_review_requests_path(universe_slug: @universe.slug),
      text: "1"
  end

  test "the entry follows the queue it opens" do
    get universe_review_requests_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select "a.sidebar-link[href=?][aria-current=page]",
      universe_review_requests_path(universe_slug: @universe.slug), count: 1

    get universe_review_request_path(universe_slug: @universe.slug, id: review_request)

    assert_response :success
    assert_select "a.sidebar-link[href=?][aria-current=page]",
      universe_review_requests_path(universe_slug: @universe.slug), count: 1
  end

  test "the queue is reachable in a mode that cannot make a submission" do
    # The mode is enforced on the one control that makes a submission
    # (`DraftsController#submit`), not on the reviewer's pages, so hiding the entry
    # would be a way of losing a queue the owner is still allowed to read.
    @universe.update!(collaboration_mode: "wikipedia")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select "a.sidebar-link[href=?]", universe_review_requests_path(universe_slug: @universe.slug), count: 1
  end

  test "a decision lowers the figure on the page it redirects to" do
    request_record = review_request

    post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record)
    assert_response :see_other

    follow_redirect!

    assert_response :success
    # Uncached, so this is the one sidebar figure that cannot be a stale copy of a
    # decision the reader has just taken.
    assert_select "a.sidebar-link[href=?] .sidebar-count", universe_review_requests_path(universe_slug: @universe.slug),
      text: "0"
  end

  private
    def review_request(universe: nil, by: nil)
      universe ||= @universe
      draft = Draft.create!(user: by || @author, universe: universe)
      draft.draft_changes.create!(action: "create", record_type: "Character", record_id: nil, base_version: nil,
        payload: { "name" => "A remembered character", "universe_id" => universe.id })
      draft.submit!
    end

    # The partial unique index on `[user_id, universe_id]` over the open statuses means
    # one author cannot have two submissions in flight at once, so a second row needs a
    # second author — the same third person `review_requests_controller_test.rb` builds.
    def third_author
      @third_author ||= User.create!(name: "User Three", email_address: "three@example.com", password: "password")
    end
end
