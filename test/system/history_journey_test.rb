require "application_system_test_case"

# The universe's change history, in a real browser.
#
# The request suite owns the rows, the day grouping, and the authorization
# (`histories_controller_test.rb`). What only a browser shows is that the page is
# **reachable from where a reader already is** — an admin answers "what happened here"
# from the sidebar of any page, and the figure beside the entry has to lower itself the
# moment a draft closes, which is the one thing the sidebar's counts do not promise.
class HistoryJourneyTest < ApplicationSystemTestCase
  setup do
    @owner = users(:user_one)
    @universe = universes(:universe_one)
    @universe.update!(collaboration_mode: "wikipedia")
  end

  test "an owner finds the history from the sidebar, and its figure follows the runs" do
    sign_in_via_form(@owner)
    visit universe_characters_path(universe_slug: @universe.slug)

    # **Nothing has happened yet, and the entry says zero rather than disappearing.**
    # It is also the only way into the page, so an entry that appeared and vanished with
    # a count would be an entry whose absence needs explaining.
    within "aside.right-sidebar" do
      assert_selector "a", text: "Change history"
      assert_selector "a[href='#{universe_history_path(universe_slug: @universe.slug)}'] .sidebar-count", text: "0"
    end

    # Remember something and close it, the way a run does.
    draft = Draft.open_for!(@owner, @universe)
    draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Written in the browser", "universe_id" => @universe.id })
    close_as_applied(draft)

    visit universe_characters_path(universe_slug: @universe.slug)

    within "aside.right-sidebar" do
      assert_selector "a[href='#{universe_history_path(universe_slug: @universe.slug)}'] .sidebar-count", text: "1"
      click_on "Change history"
    end

    # The day it closed is a heading, the run is under it, and the change is a row that
    # links to the draft whose payload it is.
    assert_selector "h1", text: "Change history"
    assert_selector ".history-day-heading"
    assert_selector ".history-draft", text: "1 remembered change"
    assert_selector ".draft-history", text: /Applied/
    assert_selector ".draft-change", text: "Written in the browser"

    click_on "1 remembered change"

    assert_selector "h1", text: "Changes to review"
    assert_selector ".draft-change", text: "Written in the browser"
  end

  test "a writer is not offered the history, because the list names every author" do
    sign_in_via_form(users(:user_two))
    visit universe_characters_path(universe_slug: @universe.slug)

    within "aside.right-sidebar" do
      assert_no_selector "a", text: "Change history"
    end
  end

  test "a direct universe has no history to reach, so there is no entry" do
    @universe.update!(collaboration_mode: "direct")
    sign_in_via_form(@owner)
    visit universe_characters_path(universe_slug: @universe.slug)

    # **Nothing can ever be listed in a `direct` universe** — the remembering path does
    # not run there, so there is no draft, so there is no run — and an entry that can
    # only lead to an empty page is noise.
    within "aside.right-sidebar" do
      assert_no_selector "a", text: "Change history"
    end
  end

  private
    # Close a draft the way the applier does, because that is what writes `closed_at`,
    # the run's tally, and the outcome rows this page reads.
    def close_as_applied(draft)
      draft.reload
      draft.draft_changes.each do |change|
        next if change.outcome.present?

        DraftChangeOutcome.create!(draft: draft, draft_change: change, state: "written")
      end
      draft.update!(status: "applied", closed_at: Time.current,
        applied_count: draft.draft_changes.count, skipped_count: 0, kept_count: 0)
    end
end
