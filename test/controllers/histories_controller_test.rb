require "test_helper"

# What has happened to a universe's content: every closed draft, grouped by the day
# it closed.
#
# The request suite owns the rows, the grouping, and the authorization — the half no
# browser shows: that the page is the owner and the admins and nobody else, that a
# draft in another universe is absent rather than a row somebody's list leaked, that a
# discarded draft is listed and says it wrote nothing, and that the day heading is the
# day the run happened rather than the day the change was remembered.
#
# What only a browser shows is the journey, in `test/system/history_journey_test.rb`.
class HistoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @owner = users(:user_one)
    @author = users(:user_two)
    sign_in_as(@owner)
  end

  # The page

  test "the page lists every closed draft in this universe and no open one" do
    applied = closed_draft(remember_create("Written by a run"), status: "applied", closed_at: 2.days.ago)
    discarded = closed_draft(remember_create("Thrown away"), status: "discarded", closed_at: 2.days.ago)
    # An open draft is pending work, not history: it belongs to **Pending changes**, and
    # listing it here would give one draft two homes.
    Draft.create!(user: @author, universe: @universe)
    elsewhere = closed_draft(remember_create("Another universe"), status: "applied",
      closed_at: 2.days.ago, universe: universes(:universe_two))

    get universe_history_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".history-draft", count: 2
    assert_select "a[href=?]", universe_draft_path(universe_slug: @universe.slug, id: applied), count: 1
    # **A discarded draft is history too.** Leaving it out would answer "who changed
    # this universe" with a list that silently drops the work somebody threw away,
    # which is the half an admin is likelier to need.
    assert_select "a[href=?]", universe_draft_path(universe_slug: @universe.slug, id: discarded), count: 1
    # Another universe's run is not this universe's history.
    assert_select "a[href=?]", universe_draft_path(universe_slug: universes(:universe_two).slug, id: elsewhere),
      count: 0
  end

  test "a discarded draft says it wrote nothing, and an applied one says what it wrote" do
    closed_draft(remember_create("Written by a run"), status: "applied",
      closed_at: 2.days.ago, applied_count: 1)
    closed_draft(remember_create("Thrown away"), status: "discarded", closed_at: 2.days.ago)

    get universe_history_url(universe_slug: @universe.slug)

    assert_response :success
    # Read from the same helper a draft's own page uses, so this page and that one
    # cannot report two different runs for one draft.
    assert_select ".draft-history", text: /Applied/
    assert_select ".draft-history", text: /1 remembered change is live/
    assert_select ".draft-history", text: /Discarded/
    assert_select ".draft-history", text: /Nothing was written/
  end

  test "the changes of a closed draft are the rows a draft's own page draws" do
    target = closed_draft(remember_create("Remembered on the way in"), status: "applied", closed_at: 2.days.ago)
    record_written(target)

    get universe_history_url(universe_slug: @universe.slug)
    listed = css_select(".draft-change").first.text.squish

    # **Read as the author, not as the admin.** The two rows have to match across two
    # different readers, because they do: the history page is an admin reading somebody
    # else's draft, and the draft's own page is its author reading it. A draft is 404
    # for anyone but its author, so signing out is what makes this comparison possible
    # at all rather than skipping it.
    sign_out
    sign_in_as(@author)
    get universe_draft_url(universe_slug: @universe.slug, id: target)
    shown = css_select(".draft-change").first.text.squish

    # The same partial, so the same reading of a remembered value: a history list and a
    # draft's page that composed their own row would eventually disagree about what a
    # change said.
    assert_equal shown, listed
    assert_match(/Remembered on the way in/, listed)
  end

  test "each change carries the outcome the run stored, so a written one is told from a skipped one" do
    applied = closed_draft(remember_create("Written by a run"), status: "applied", closed_at: 2.days.ago)
    record_written(applied)
    kept = closed_draft(remember_create("Kept as it was"), status: "applied", closed_at: 2.days.ago)
    DraftChangeOutcome.create!(draft: kept, draft_change: kept.draft_changes.sole,
      state: "moved", answer: "theirs")

    get universe_history_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-change-outcome", text: "Live", count: 1
    assert_select ".draft-change-outcome", text: /Kept/, count: 1
  end

  test "the author is named, because this is the page where it is not implied" do
    closed_draft(remember_create("By somebody else"), status: "applied",
      closed_at: 2.days.ago, by: @author)

    get universe_history_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".history-draft", text: /#{Regexp.escape(@author.name)}/
  end

  test "a universe with no runs says so rather than showing an empty list" do
    Draft.create!(user: @author, universe: @universe)

    get universe_history_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".empty-state", text: /Nothing has changed yet/
    assert_select ".history-day", count: 0
  end

  # Grouping by day

  test "runs are grouped under the day they closed, newest day first" do
    # **Fixed clock times, not `5.days.ago + 2.hours`.** A relative time carries the
    # current time of day, so adding hours to it crosses midnight and the two runs meant
    # to share a day do not. The grouping is by calendar day, so the test has to place
    # both runs inside one day deliberately.
    older = closed_draft(remember_create("Older"), status: "applied",
      closed_at: Time.zone.local(2026, 3, 4, 9, 0))
    same_day = closed_draft(remember_create("Same day, later"), status: "applied",
      closed_at: Time.zone.local(2026, 3, 4, 17, 30))
    newer = closed_draft(remember_create("Newer"), status: "applied",
      closed_at: Time.zone.local(2026, 3, 6, 11, 0))

    get universe_history_url(universe_slug: @universe.slug)

    assert_response :success
    days = css_select(".history-day-heading").map { |heading| heading.text.squish }
    # **The heading is the day the run happened**, not the day the change was
    # remembered: a reader asking what the universe looked like on Tuesday is asking
    # about runs, not about intentions.
    assert_equal [ I18n.l(Date.new(2026, 3, 6), format: :long), I18n.l(Date.new(2026, 3, 4), format: :long) ], days

    groups = css_select(".history-day")
    # Newest day first: the answer to "what happened lately" is at the top.
    assert_equal 1, groups.first.css(".history-draft").size
    assert_includes groups.first.text, "Newer"
    # Two runs on one day are one group, and both of them are in it: the grouping
    # relocates the drafts, it does not drop any.
    assert_equal 2, groups.last.css(".history-draft").size
    assert_includes groups.last.text, older.draft_changes.sole.payload["name"]
    assert_includes groups.last.text, same_day.draft_changes.sole.payload["name"]
  end

  test "a change remembered days before it was written is dated by the run" do
    target = closed_draft(remember_create("Remembered long ago"), status: "applied", closed_at: 1.day.ago)
    # The change's own moment is deliberately earlier than the run's: this is the case
    # that separates `closed_at` from `created_at`.
    target.draft_changes.update_all(created_at: 6.days.ago)

    get universe_history_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".history-day-heading", text: I18n.l(1.day.ago.to_date, format: :long)
    assert_select ".history-day-heading", text: I18n.l(6.days.ago.to_date, format: :long), count: 0
  end

  test "the history is rendered in Spanish as well as English" do
    # The key sets being equal is `translations_test.rb`'s job; what it cannot see is a
    # plural form or an interpolation that only renders wrong in the second language,
    # and `raise_on_missing_translations` makes a missing key raise here rather than
    # fall back to English. The day heading is the case that matters: it is written by
    # `I18n.l(date, format: :long)`, and `time.formats.long` is one of the keys this
    # project's own `es.yml` has to supply rather than inherit.
    closed_draft(remember_create("Escrito en el navegador"), status: "applied", closed_at: 2.days.ago)
    # The language is a browser preference carried in a **signed** cookie, so it is set
    # the way a reader sets it — through the settings action — rather than written onto
    # the jar unsigned, which the signed reader refuses.
    patch settings_url, params: { locale: "es" }

    get universe_history_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: I18n.t("histories.index.title", locale: :es)
    assert_select ".history-draft", text: /1 cambio recordado/
    assert_select ".draft-history", text: /Aplicado/
    assert_select ".history-day-heading", text: I18n.l(2.days.ago.to_date, format: :long, locale: :es)
  end

  # Authorization

  test "an admin reads the whole universe's history" do
    closed_draft(remember_create("Somebody else's work"), status: "applied",
      closed_at: 2.days.ago, by: @author)

    get universe_history_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".history-draft", count: 1
  end

  test "a writer is refused, because the list names every author who has closed a draft" do
    closed_draft(remember_create("Not theirs to read"), status: "applied", closed_at: 2.days.ago)

    sign_out
    sign_in_as(@author)

    get universe_history_url(universe_slug: @universe.slug)

    # **The whole controller, not two of its actions.** There is one action, and it is
    # admin's, for the review queue's reason: a list that names other people's work is
    # itself the answer, and a plain writer has no business reading it.
    assert_response :forbidden
  end

  test "a non-member is refused, and a guest is sent to sign in" do
    closed_draft(remember_create("Not theirs to read"), status: "applied", closed_at: 2.days.ago)

    sign_out
    sign_in_as(@author)
    UniverseMembership.find_by(user: @author, universe: @universe)&.destroy

    get universe_history_url(universe_slug: @universe.slug)

    # A public universe grants every signed-in user write, and admin is not write: the
    # gate is the access level, not the membership's existence.
    assert_response :forbidden

    sign_out
    get universe_history_url(universe_slug: @universe.slug)

    assert_redirected_to new_session_url
  end

  test "a history page in a universe that does not exist is a 404" do
    get universe_history_url(universe_slug: "no-such-universe")

    assert_response :not_found
  end

  private
    # A closed draft, which is what the page lists. `closed_at` and the run's tally are
    # written here rather than inferred: the model requires `closed_at` on a closed
    # draft, and the applier and the discard action are the two things that write both
    # columns in the application.
    def closed_draft(*changes, status: "applied", closed_at:, universe: nil, by: nil, applied_count: nil)
      draft = Draft.create!(user: by || @author, universe: universe || @universe,
        status: status, closed_at: closed_at, applied_count: applied_count || 0)
      changes.each { |attributes| draft.draft_changes.create!(attributes) }
      draft
    end

    # No scope column in the payload: the applier places a create in the draft's own
    # universe, and these drafts are never applied by this suite.
    def remember_create(name)
      { action: "create", record_type: "Character", record_id: nil, base_version: nil,
        payload: { "name" => name } }
    end

    # The outcome a run stores beside a change it wrote, which is what the change's own
    # row is badged from. Written the way `DraftApplier` writes it: one row per change,
    # validated against its own draft.
    def record_written(draft)
      draft.draft_changes.each do |change|
        DraftChangeOutcome.create!(draft: draft, draft_change: change, state: "written")
      end
    end
end
