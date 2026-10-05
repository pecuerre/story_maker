require "application_system_test_case"

# The collaborators list and one person's history, in a real browser.
#
# The request suite owns the counts, the 404, and the authorization
# (`collaborators_controller_test.rb`). What only a browser shows is the journey: an
# admin answers "who has worked on this universe" from the sidebar of any page, sees
# their figure, follows a person, and lands on the same rows the universe history
# draws — narrowed to one author.
class CollaboratorsJourneyTest < ApplicationSystemTestCase
  setup do
    @owner = users(:user_one)
    @author = users(:user_two)
    @universe = universes(:universe_one)
    @universe.update!(collaboration_mode: "wikipedia")
  end

  test "an owner finds who has changed this universe, and follows one of them" do
    closed_draft(3, by: @owner)
    closed_draft(1, by: @author)
    sign_in_via_form(@owner)
    visit universe_characters_path(universe_slug: @universe.slug)

    # **Two figures that count different things**, both in the same group: this one
    # counts people, the change history beside it counts runs. A reader has to be able
    # to ask "how many of us" and "how much" and get an answer to each.
    within "aside.right-sidebar" do
      assert_selector "a[href='#{universe_collaborators_path(universe_slug: @universe.slug)}'] .sidebar-count", text: "2"
      assert_selector "a[href='#{universe_history_path(universe_slug: @universe.slug)}'] .sidebar-count", text: "2"
      click_on "Collaborators"
    end

    # **The path is asserted, not the heading.** A Turbo navigation outlives Capybara's
    # click, so a heading read straight afterwards can still be the page that was left;
    # `assert_current_path` waits for the navigation rather than for a selector that
    # happens to be there. This is the same `REFRESH_WAIT` the rest of the browser suite
    # uses after a mutation, for the same reason.
    assert_current_path universe_collaborators_path(universe_slug: @universe.slug), wait: REFRESH_WAIT
    assert_selector "h1", text: "Collaborators"
    assert_selector ".collaborator-row", count: 2
    # Most active first.
    within ".collaborator-row", text: @owner.name do
      assert_text "3 remembered changes"
    end
    within ".collaborator-row", text: @author.name do
      assert_text "1 remembered change"
    end

    # The row's one navigation, not its title: every list row here names its subject in
    # a span and links on the right.
    within ".collaborator-row", text: @owner.name do
      click_on "History"
    end

    # **The same rows the universe history draws, narrowed to one author.** The heading
    # is the person's name, and their name is not repeated on every row because the
    # page is already about them.
    assert_current_path universe_collaborator_path(universe_slug: @universe.slug, id: @owner), wait: REFRESH_WAIT
    assert_selector "h1", text: @owner.name
    assert_selector ".history-day-heading"
    assert_selector ".history-draft", text: "3 remembered changes"
    assert_selector ".draft-change", count: 3
    assert_no_selector ".history-draft-header", text: @owner.name
  end

  test "a writer is not offered the collaborators, because the list names every author" do
    closed_draft(1, by: @author)
    sign_in_via_form(@author)
    visit universe_characters_path(universe_slug: @universe.slug)

    within "aside.right-sidebar" do
      assert_no_selector "a", text: "Collaborators"
      assert_no_selector "a", text: "Change history"
    end
  end

  private
    # A closed draft with `count` remembered creates, closed the way the applier closes
    # one, because that is what writes `closed_at` and makes the draft history.
    def closed_draft(count, by:)
      draft = Draft.create!(user: by, universe: @universe, status: "applied",
        closed_at: Time.current, applied_count: count)
      count.times do |index|
        draft.draft_changes.create!(action: "create", record_type: "Character",
          payload: { "name" => "Created #{index} by #{by.name}", "universe_id" => @universe.id })
      end
      draft
    end
end
