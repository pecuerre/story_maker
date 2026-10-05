require "test_helper"

# Who has changed a universe, and what one of them changed.
#
# The request suite owns the list, the counts, the 404, and the authorization — the half
# no browser shows: that a collaborator is somebody who *closed a draft here* rather
# than somebody who was invited, that a discarded run counts, that the two figures on
# the page count different things on purpose, and that the per-person page is the
# universe history narrowed rather than a second list of its own.
#
# What only a browser shows is the journey, in `test/system/collaborators_journey_test.rb`.
class CollaboratorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @owner = users(:user_one)
    @author = users(:user_two)
    sign_in_as(@owner)
  end

  # The list

  test "the list names everybody who has closed a draft here, with their change counts" do
    mine = closed_draft(2, by: @owner)
    theirs = closed_draft(5, by: @author)
    DraftChange.create!(action: "create", record_type: "Character", draft: mine,
      payload: { "name" => "One more" })

    get universe_collaborators_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".collaborator-row", count: 2
    # Most active first, which is the order a reader scans for "who did the most here".
    rows = css_select(".collaborator-row .entity-description").map { |row| row.text.squish }
    assert_equal [ I18n.t("collaborators.index.changes", count: 5), I18n.t("collaborators.index.changes", count: 3) ], rows
    assert_select "a[href=?]", universe_collaborator_path(universe_slug: @universe.slug, id: @author)
    assert_select "a[href=?]", universe_collaborator_path(universe_slug: @universe.slug, id: @owner)
    # **The name is a plain span and the row carries exactly one link.** A list row in
    # this application names its record in an `entity-title` span and puts navigation on
    # the right, so a title that is also a link would be a second destination on the row
    # pointing at the same place — and `link_to(path, class:)` with a bare path as its
    # first argument renders *that path* as the body, which is what a naive version of
    # this row showed. Asserting the count catches both.
    assert_select ".collaborator-row .entity-title", text: @owner.name
    assert_select ".collaborator-row .entity-title", text: @author.name
    assert_select ".collaborator-row .entity-title", text: /\/collaborators\/\d+/, count: 0
    # One link per row, so the count is the row count rather than a number.
    assert_select ".collaborator-row a", count: 2
  end

  test "a member who has never edited anything is not a collaborator, and a writer who has is" do
    # **A collaborator is read from the drafts, not from the memberships.** A member
    # who has changed nothing has not collaborated, and a person who has changed
    # something was never a member: a public universe grants write to every signed-in
    # user, so most of the people who have edited here have no membership row at all.
    UniverseMembership.create!(user: a_third_user, universe: @universe, access_level: "read")
    closed_draft(1, by: @author)

    get universe_collaborators_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".collaborator-row", count: 1
    assert_select ".collaborator-row a[href=?]",
      universe_collaborator_path(universe_slug: @universe.slug, id: @author)
    assert_select "a[href=?]", universe_collaborator_path(universe_slug: @universe.slug, id: a_third_user),
      count: 0
  end

  test "an open draft is pending work, not a collaboration yet" do
    Draft.create!(user: @author, universe: @universe)

    get universe_collaborators_url(universe_slug: @universe.slug)

    assert_response :success
    # Nothing has closed, so nobody has collaborated. The draft belongs to **Pending
    # changes**, which is where pending work is read.
    assert_select ".collaborator-row", count: 0
  end

  test "a discarded run counts, because remembering a change here is collaborating here" do
    closed_draft(3, by: @author, status: "discarded")

    get universe_collaborators_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".collaborator-row", count: 1
    assert_select ".collaborator-row .entity-description", text: /3 remembered changes/
    # The page has to say what the number means, because nothing in the model marks
    # these changes as never having been written.
    assert_select ".page-description", text: /written or thrown away/
  end

  test "a run in another universe is not a collaboration here" do
    closed_draft(2, by: @author, universe: universes(:universe_two))

    get universe_collaborators_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".collaborator-row", count: 0
  end

  test "a universe where nothing has happened says so rather than showing an empty list" do
    get universe_collaborators_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".empty-state", text: /Nobody has changed anything yet/
    assert_select ".collaborator-row", count: 0
  end

  # One person

  test "a collaborator's page is their closed drafts, grouped by day, in the history's own rows" do
    target = closed_draft(2, by: @author, closed_at: Time.zone.local(2026, 5, 1, 10, 0))
    closed_draft(1, by: @author, closed_at: Time.zone.local(2026, 5, 3, 10, 0))
    closed_draft(4, by: @owner, closed_at: Time.zone.local(2026, 5, 2, 10, 0))

    get universe_collaborator_url(universe_slug: @universe.slug, id: @author)

    assert_response :success
    assert_select "h1", text: @author.name
    # **Only this author's runs.** Somebody else's work on the same day is not on this
    # page, which is the one thing that distinguishes it from the universe history.
    assert_select ".history-day", count: 2
    assert_select ".history-day-heading", text: I18n.l(Date.new(2026, 5, 3), format: :long)
    assert_select ".history-day-heading", text: I18n.l(Date.new(2026, 5, 2), format: :long), count: 0
    # The header's figure is remembered changes, which is what the reader is about to read.
    assert_select ".page-header .badge", text: "3"
  end

  test "the same run draws the same rows on both pages" do
    target = closed_draft(2, by: @author, status: "discarded", closed_at: 2.days.ago)
    target.draft_changes.each do |change|
      DraftChangeOutcome.create!(draft: target, draft_change: change, state: "written")
    end

    get universe_history_url(universe_slug: @universe.slug)
    universe_rows = css_select(".history-draft, .draft-change").map { |row| row.text.squish }

    get universe_collaborator_url(universe_slug: @universe.slug, id: @author)
    person_rows = css_select(".history-draft, .draft-change").map { |row| row.text.squish }

    # **The two pages share `histories/_day` and `drafts/_change`**, so a run cannot be
    # reported one way on the universe's history and another way on the author's own.
    # The author's name is the one deliberate difference: the per-person page's heading
    # is already that name, so its rows do not repeat it.
    assert_equal universe_rows.size, person_rows.size
    assert_equal universe_rows.map { |row| row.sub(@author.name, "").squish },
      person_rows.map { |row| row.sub(@author.name, "").squish }
  end

  test "the author's own name is not repeated on every row of their own page" do
    closed_draft(2, by: @author)

    get universe_history_url(universe_slug: @universe.slug)
    assert_select ".history-draft-header", text: /#{Regexp.escape(@author.name)}/

    get universe_collaborator_url(universe_slug: @universe.slug, id: @author)

    assert_response :success
    # It is the page's heading and not a finding on each of its rows.
    assert_select "h1", text: @author.name
    assert_select ".history-draft-header", text: /#{Regexp.escape(@author.name)}/, count: 0
  end

  # Authorization

  test "a writer is refused, because the list names every author who has closed a draft" do
    closed_draft(2, by: @author)

    sign_out
    sign_in_as(@author)

    get universe_collaborators_url(universe_slug: @universe.slug)

    # The whole controller, and the same gate as the change history it is derived from.
    assert_response :forbidden
  end

  test "a writer cannot open a collaborator's page either" do
    closed_draft(2, by: @author)

    sign_out
    sign_in_as(@author)

    get universe_collaborator_url(universe_slug: @universe.slug, id: @owner)

    assert_response :forbidden
  end

  test "a guest is sent to sign in" do
    sign_out

    get universe_collaborators_url(universe_slug: @universe.slug)

    assert_redirected_to new_session_url
  end

  test "somebody who has not collaborated here is a 404, not an empty page" do
    # **The lookup is scoped through the universe's closed drafts.** A user who exists
    # but has never changed anything here is a person this page knows nothing about, and
    # answering with an empty list would confirm the id is somebody's at all.
    stranger = a_third_user
    closed_draft(2, by: @author)

    get universe_collaborator_url(universe_slug: @universe.slug, id: stranger)

    assert_response :not_found

    get universe_collaborator_url(universe_slug: @universe.slug, id: 0)

    assert_response :not_found
  end

  test "a collaborator from another universe is a 404 here" do
    closed_draft(2, by: @author, universe: universes(:universe_two))

    get universe_collaborator_url(universe_slug: @universe.slug, id: @author)

    assert_response :not_found
  end

  test "the page is rendered in Spanish as well as English" do
    closed_draft(2, by: @author)
    # The language is a browser preference carried in a **signed** cookie, so it is set
    # the way a reader sets it rather than written onto the jar unsigned.
    patch settings_url, params: { locale: "es" }

    get universe_collaborators_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: I18n.t("collaborators.index.title", locale: :es)
    assert_select ".collaborator-row .entity-description", text: /2 cambios recordados/
  end

  private
    # A third person, for the cases that need somebody who is in the universe in a way
    # that does not make them a collaborator. There are only two user fixtures, and one
    # of them is the owner, so this is created rather than reached for.
    def a_third_user
      @a_third_user ||= User.create!(name: "User Three", email_address: "three@example.com", password: "password")
    end

    # A closed draft with `count` remembered creates, which is what a run leaves.
    def closed_draft(count, by:, status: "applied", closed_at: Time.current, universe: nil)
      draft = Draft.create!(user: by, universe: universe || @universe,
        status: status, closed_at: closed_at, applied_count: status == "applied" ? count : 0)
      count.times do |index|
        draft.draft_changes.create!(action: "create", record_type: "Character",
          payload: { "name" => "Created #{index}" })
      end
      draft
    end
end
