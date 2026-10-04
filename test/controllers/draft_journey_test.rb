require "test_helper"

# The whole `wikipedia` journey as one request sequence: start editing, make
# changes, see them in the lists, apply, see them live.
#
# Every step of this is held elsewhere, and none of those files can see the seam
# between them. `draft_mutation_test.rb` walks all twenty mutation controllers to
# prove a mutation is remembered rather than written;
# `draft_pending_list_test.rb` renders a draft the test built by hand, with no
# request that remembered anything; `drafts_controller_test.rb` reads and applies a
# draft the test built the same way; and `draft_workflow_test.rb` /
# `draft_pending_changes_test.rb` cover the same halves in a browser, one journey
# at a time. What none of them asserts is that the *same* author's remembered
# create, edit, and delete survive the whole round trip: that the draft the apply
# writes is the draft the lists were reading, and that a row badged as pending
# before the apply is the record the apply writes.
#
# That is the property a reader experiences and none of the parts carries, so it is
# asserted here in one pass, over requests rather than over objects — a change is
# remembered *by a request*, a pending row is rendered by a request, and only an
# apply request closes the loop.
class DraftJourneyTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_one)
    @universe.update!(collaboration_mode: "wikipedia")
    sign_in_as(@user)
  end

  test "an author's remembered create, edit, and deletion become live records on one apply" do
    edited = characters(:character_one)
    removed = characters(:character_two)

    # **Start editing.** The control is a claim, not a gate (ADR 0022), so this step
    # opens the draft rather than switching anything on — which is why the steps
    # after it work whether or not it was pressed.
    post universe_editing_url(universe_slug: @universe.slug)

    assert_redirected_to universe_url(universe_slug: @universe.slug)
    assert_equal I18n.t("drafts.flash.editing_started"), flash[:notice]
    draft = Draft.open_for(@user, @universe)
    assert_not_nil draft, "starting an editing session opens the draft before anything is remembered"

    # **Make changes.** All three actions on one workspace, on three different
    # records, so the draft holds one change of every kind and the apply below has
    # to handle all of them. Two of them cannot share a record: a deletion wins an
    # edit on the same record in the lists, which would leave the edit with nothing
    # to prove.
    post universe_characters_url(universe_slug: @universe.slug),
      params: { character: { name: "Remembered on the way in" } }, as: :json
    assert_response :accepted
    patch universe_character_url(universe_slug: @universe.slug, id: edited.id),
      params: { character: { name: "Renamed on the way in" } }, as: :json
    assert_response :accepted
    delete universe_character_url(universe_slug: @universe.slug, id: removed.id), as: :json
    assert_response :accepted

    assert_nil Character.find_by(name: "Remembered on the way in")
    assert_equal edited.name, edited.reload.name, "a remembered rename must not be written"
    assert_predicate removed, :present?, "a remembered deletion must not have deleted anything"
    assert_equal 3, draft.draft_changes.count

    # **See them in the lists.** The same three changes, read the way the author
    # reads them: a row for the record that does not exist yet, a badge on the one
    # being edited, a badge on the one being removed, and one count for all of it
    # in the sidebar.
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-row .entity-title", text: "Remembered on the way in"
    assert_equal [ I18n.t("drafts.pending.states.edit") ], pending_badges_on(edited.name)
    assert_equal [ I18n.t("drafts.pending.states.deletion") ], pending_badges_on(removed.name)
    assert_select ".draft-pending-panel .draft-pending-summary", text: I18n.t("drafts.pending.count", count: 3)

    # **The drafts page**, which is where the three are acted on.
    get universe_drafts_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".entity-row .entity-title", text: I18n.t("drafts.index.changes", count: 3)

    # **Apply.**
    post apply_universe_draft_url(universe_slug: @universe.slug, id: draft)

    assert_redirected_to universe_draft_url(universe_slug: @universe.slug, id: draft)
    assert_equal I18n.t("drafts.flash.applied", count: 3), flash[:notice]

    # **See them live**, with nothing left pending: the three records the lists were
    # reading about are the three records the apply wrote, which is the only
    # evidence that the pending rows were about *these* changes.
    assert_equal "Remembered on the way in", Character.find_by(name: "Remembered on the way in").name
    assert_equal "Renamed on the way in", edited.reload.name
    assert_nil Character.find_by(id: removed.id)
    assert_equal "applied", draft.reload.status

    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-row", count: 0
    assert_select ".draft-pending-badge", count: 0
    assert_select ".draft-pending-panel .draft-pending-summary", text: I18n.t("drafts.pending.count", count: 0)
    assert_select ".entity-row .entity-title", text: "Remembered on the way in"
  end

  test "an author resolves a conflict on the way to applying, in wikipedia mode" do
    character = characters(:character_one)

    patch universe_character_url(universe_slug: @universe.slug, id: character.id),
      params: { character: { name: "Renamed by the author" } }, as: :json
    assert_response :accepted

    # Somebody else renames the same record before the author applies, which is the
    # move `base_version` exists to notice.
    character.update!(name: "Renamed by somebody else")

    draft = Draft.open_for(@user, @universe)
    post apply_universe_draft_url(universe_slug: @universe.slug, id: draft)

    # The apply stops and asks rather than writing: a 422 on this action, which is
    # the only conflict page in the application, and nothing is written while the
    # question is open.
    assert_response :unprocessable_content
    assert_equal I18n.t("drafts.conflicts.title"), css_select("h1").first.text
    assert_predicate draft, :open?, "a refused apply leaves the draft exactly as it was"
    assert_equal "Renamed by somebody else", character.reload.name

    post apply_universe_draft_url(universe_slug: @universe.slug, id: draft),
      params: { resolutions: { draft.draft_changes.first.id.to_s => "mine" } }

    assert_redirected_to universe_draft_url(universe_slug: @universe.slug, id: draft)
    assert_equal "Renamed by the author", character.reload.name
    assert_equal "applied", draft.reload.status
  end

  test "the journey's pages say what it is, and only where it can happen" do
    # The copy a first-time author needs is a page of its own: the lists badge a
    # remembered change and the flash says one was remembered, but neither says what
    # happens next, and the drafts list is where that question is answered. It is
    # rendered on both drafts pages because the list and the draft are one place in
    # this workflow.
    get universe_drafts_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-workflow-guide li", count: 3
    assert_select ".draft-workflow-guide li:last-of-type", text: I18n.t("drafts.guide.steps.apply")

    draft = Draft.open_for!(@user, @universe)
    draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Waiting", "universe_id" => @universe.id })

    get universe_draft_url(universe_slug: @universe.slug, id: draft)

    assert_response :success
    assert_select ".draft-workflow-guide li", count: 3

    # A `direct` universe never opens a draft, so the steps would describe a workflow
    # that does not happen there.
    @universe.update!(collaboration_mode: "direct")
    get universe_drafts_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-workflow-guide", count: 0
  end

  private
    # The pending badges on the one row naming `name`, read out of the rendered page.
    #
    # A row's badge has to be attributed to *that* row, and a count across the page
    # cannot do it: the journey badges two records at once, and a page-wide count
    # would be satisfied by one row wearing the wrong badge. The badge word itself is
    # the assertion too, so a row badged `edit` where the draft holds a `delete`
    # fails here.
    def pending_badges_on(name)
      row = css_select(".entity-row").find { |element| element.text.include?(name) }

      assert_not_nil row, "no row in the list names #{name}"

      row.css(".draft-pending-badge").map { |badge| badge.text.strip }
    end
end
