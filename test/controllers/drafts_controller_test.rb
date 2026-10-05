require "test_helper"

# One author's remembered changes, and the two decisions an author can make
# about them.
#
# The request path that *remembers* a change is covered by
# `test/controllers/draft_mutation_test.rb`, across all twenty mutation
# controllers. What is covered here is the other end: that a draft is read as its
# own author's, that applying it writes through the live mutation path rather than
# around it, and that the one failure this must not have — applying twice — is
# impossible rather than merely unlikely.
class DraftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @user = users(:user_one)
    @character = characters(:character_one)
    sign_in_as(@user)
  end

  # The list
  #
  # `index` and `show` are reads, so they answer `read` access; `apply` and
  # `discard` are writes, so the shared universe policy asks for `write`. Both
  # halves of that are asserted here rather than left to the shared callback's own
  # tests, because this controller is the first one where the two are different
  # actions in the same page.

  test "the list shows this author's drafts in this universe" do
    mine = draft_with(remember_create_payload)
    other_universe = Draft.create!(user: @user, universe: universes(:universe_two))
    other_universe.draft_changes.create!(action: "create", record_type: "Character", payload: { "name" => "Elsewhere" })
    someone_else = Draft.create!(user: users(:user_two), universe: @universe)
    someone_else.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Theirs", "universe_id" => @universe.id })

    get universe_drafts_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".content-surface .entity-row", count: 1
    assert_select "a[href=?]", universe_draft_path(universe_slug: @universe.slug, id: mine), count: 1
    assert_select ".entity-title", text: "1 remembered change"
    # Somebody else's unfinished work is not published by the universe it is in,
    # and a draft is authorized inside one universe rather than globally.
    assert_select "a[href=?]", universe_draft_path(universe_slug: @universe.slug, id: someone_else), count: 0
    assert_select "a[href=?]", universe_draft_path(universe_slug: universes(:universe_two).slug, id: other_universe),
      count: 0
  end

  test "the draft that can still be acted on is the first one in the list" do
    history = draft_with(remember_create_payload("Applied"), closed: "applied")
    open = draft_with(remember_create_payload("Still open"))

    get universe_drafts_url(universe_slug: @universe.slug)

    assert_response :success
    # Read in the order the page renders them: the actionable draft first, then
    # the history, each newest-first inside its own group.
    assert_equal [ open.id, history.id ], css_select(".entity-row a.btn-outline-secondary").map { |link| link["href"].split("/").last.to_i }
  end

  test "an author with no drafts is told the list is empty" do
    get universe_drafts_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".empty-state", text: /Nothing is waiting to be applied/
  end

  test "a read-only member reads their own drafts and cannot apply one" do
    # A read level only exists in a private universe: a public one grants every
    # signed-in user write regardless of what a membership row says, which is why
    # the membership in the fixtures cannot express "this contributor may only
    # read".
    private_universe = Universe.create!(owner: @user, name: "Private one", slug: "private-one", private: true)
    membership = UniverseMembership.create!(user: users(:user_two), universe: private_universe,
      access_level: "read")
    theirs = Draft.create!(user: users(:user_two), universe: private_universe)
    theirs.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Not writable", "universe_id" => private_universe.id })
    sign_out
    sign_in_as(users(:user_two))

    get universe_drafts_url(universe_slug: private_universe.slug)

    assert_response :success

    assert_no_difference -> { Character.count } do
      post apply_universe_draft_url(universe_slug: private_universe.slug, id: theirs)
    end

    assert_response :forbidden
    assert_predicate membership, :read?
    assert_predicate theirs.reload, :draft?
  end

  test "a guest is sent to sign in rather than shown another reader's drafts" do
    draft_with(remember_create_payload)
    sign_out

    get universe_drafts_url(universe_slug: @universe.slug)

    assert_redirected_to new_session_url
  end

  # One draft in detail

  test "the page states what each remembered change would do" do
    target = draft_with(remember_update_payload("Renamed by a draft"), remember_create_payload("Remembered create"))

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    assert_select ".draft-change", count: 2
    # The changes render in the order they were remembered: an update made before a
    # create is listed before it.
    rows = css_select(".draft-change")
    assert_match(/Update/, rows.first.text)
    assert_match(/Renamed by a draft/, rows.first.text)
    assert_match(/Create/, rows.last.text)
    # A change about a record that exists links to that record's own page, built
    # from its own search declaration rather than from a route named per type.
    assert_select ".draft-change a[href=?]", @character.search_url, count: 1
  end

  test "a remembered create is titled by the type it would create, not by a record" do
    target = draft_with(remember_create_payload)

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    assert_select ".draft-change .entity-title", text: "New Character"
    assert_select ".draft-change a", count: 0
  end

  test "a remembered delete says it removes the record and lists no values" do
    target = draft_with(remember_delete_payload(@character))

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    assert_select ".draft-change", count: 1
    assert_select ".draft-change .entity-description", text: "This change removes the record."
  end

  test "a remembered tag assignment is listed by name rather than by id" do
    tag = character_tags(:character_tag_one)
    target = draft_with(remember_create_payload("Tagged", extra: { "character_tag_ids" => [ tag.id ] }))

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    assert_select ".draft-change .entity-description", text: /#{tag.name}/
    refute_includes response.body, tag.id.to_s
  end

  test "the scope column a create carries is plumbing the page does not print" do
    target = draft_with(remember_create_payload)

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    # `universe_id` is how the change knows where the record goes. The page is
    # already inside that universe, so printing the number would tell the reader
    # nothing; what it does say is the value they actually submitted.
    assert_select ".draft-change .entity-description", text: /Name/
    refute_match(/Universe/, response.body[/<div class="entity-description">.*?<\/div>/m])
  end

  test "a change whose record has since been deleted is still listed, without a link" do
    target = draft_with(remember_update_payload("Renamed by a draft"))
    @character.soft_delete

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    assert_select ".draft-change", count: 1
    assert_select ".draft-change .entity-description", text: /Renamed by a draft/
    assert_select ".draft-change a", count: 0
  end

  test "another author's draft and another universe's draft are both a 404" do
    theirs = Draft.create!(user: users(:user_two), universe: @universe)
    elsewhere = Draft.create!(user: @user, universe: universes(:universe_two))

    get universe_draft_url(universe_slug: @universe.slug, id: theirs)
    assert_response :not_found

    get universe_draft_url(universe_slug: @universe.slug, id: elsewhere)
    assert_response :not_found

    get universe_draft_url(universe_slug: @universe.slug, id: 0)
    assert_response :not_found
  end

  # The history of a closed draft.
  #
  # Before this, an apply's outcome existed only in the flash that followed it, so an
  # applied draft was a row that said when its changes were *remembered* and nothing
  # about what became of them. What is asserted here is that both surfaces now say
  # it, that they say the same thing, and that each change's own row says what
  # became of it — the whole of finding 64.

  test "a closed draft in the list says when it was closed and what its run did" do
    applied = draft_with(remember_create_payload, remember_create_payload("Second"), closed: "applied")
    applied.update!(closed_at: 3.days.ago, applied_count: 2)
    draft_with(remember_create_payload("Waiting"))

    get universe_drafts_url(universe_slug: @universe.slug)

    assert_response :success
    history = css_select(".entity-row .draft-history").first.text
    # The moment the draft stopped being actionable, and the tally of what the run
    # wrote. The remembered-at line above it is still there: a draft's history
    # does not replace what it remembered, it says what became of it.
    assert_match(/Applied/, history)
    assert_match(/#{Regexp.escape(I18n.l(3.days.ago, format: :short))}/, history)
    assert_match(/2 remembered changes are live/, history)
  end

  test "a closed draft's own page says the same history as its list row" do
    target = draft_with(remember_create_payload, closed: "applied")
    target.update!(closed_at: 2.days.ago, applied_count: 1)

    get universe_drafts_url(universe_slug: @universe.slug)
    listed = css_select(".entity-row .draft-history").first.text.squish
    get universe_draft_url(universe_slug: @universe.slug, id: target)
    shown = css_select(".draft-history").first.text.squish

    # One sentence for one fact, read by one helper: a list and a page that composed
    # their own would eventually disagree about what an apply did.
    assert_equal listed, shown
    assert_match(/1 remembered change is live/, shown)
  end

  test "each remembered change says what became of it once the apply has decided" do
    target = draft_with(
      remember_update_payload("Renamed by a draft"),
      # A create the live path will refuse, so the run has something to report.
      remember_create_payload("")
    )
    change = target.draft_changes.first
    @character.update!(name: "Renamed by somebody else", description: "Also changed by somebody else")

    post apply_universe_draft_url(universe_slug: @universe.slug, id: target),
      params: { resolutions: { change.id => "theirs" } }

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    rows = css_select(".draft-change")
    assert_equal 2, rows.size
    # The first change was decided, not refused, and the row says so in its own
    # words: a change the author chose to drop and one the universe refused are
    # different outcomes.
    assert_match(/Kept theirs/, rows[0].text)
    assert_match(/You chose theirs/, rows[0].text)
    assert_match(/Refused/, rows[1].text)
    assert_match(/would not accept this change/, rows[1].text)
    # What the author asked for is still on the row beside the outcome. A skipped
    # change stays readable, and stays redoable from the record's own page.
    assert_match(/Name: Renamed by a draft/, rows[0].text)
    assert_match(/Renamed by somebody else/, rows[0].text)
  end

  test "an open draft's changes say nothing about an outcome that has not happened" do
    target = draft_with(remember_create_payload)

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    assert_select ".draft-change-outcome", count: 0
    assert_select ".draft-change-outcome-reason", count: 0
    # No history sentence either: an open draft has no closure to report.
    assert_select ".draft-history", count: 0
    # The page is still exactly what it was before outcomes existed: what each
    # change says, and nothing more.
    assert_select ".draft-change", count: 1
    assert_select ".draft-change .entity-description", text: /Remembered create/
  end

  test "a discarded draft says when it was discarded and that nothing was written" do
    target = draft_with(remember_create_payload)

    post discard_universe_draft_url(universe_slug: @universe.slug, id: target)

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    history = css_select(".draft-history").first.text
    assert_match(/Discarded/, history)
    assert_match(/Nothing was written/, history)
    # The remembered change is still listed: rejecting a draft records the decision
    # on the draft, and does not rewrite what the change said.
    assert_select ".draft-change", count: 1
    # Nothing was applied, so no change has an outcome to be badged with.
    assert_select ".draft-change-outcome", count: 0
  end

  test "the apply's own flash and the history it leaves behind report the same run" do
    target = draft_with(remember_create_payload, remember_create_payload(""))

    post apply_universe_draft_url(universe_slug: @universe.slug, id: target)
    notice = flash[:notice]

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    history = css_select(".draft-history").first.text
    # One run, two reports: the flash scrolls away and the history is what a reader
    # comes back to. Two numbers derived separately would be two answers.
    assert_equal I18n.t("drafts.flash.partially_applied", applied: 1, skipped: 1), notice
    assert_match(/1 remembered change is live/, history)
    assert_match(/1 remembered change could not be applied/, history)
    assert_equal 1, target.reload.applied_count
    assert_equal 1, target.skipped_count
  end

  test "an empty draft states that it remembers nothing" do
    target = draft_with

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    assert_select ".empty-state", text: /This draft remembers no changes/
    assert_select ".draft-change", count: 0
  end

  test "a closed draft's history is rendered in Spanish as well as English" do
    # The key sets being equal is `translations_test.rb`'s job; what it cannot see is
    # a plural form or an interpolation that only renders wrong in the second
    # language, and `raise_on_missing_translations` makes a missing key raise here
    # rather than fall back to English.
    target = draft_with(remember_create_payload)
    # The language is a browser preference carried in a **signed** cookie, so it is
    # set the way a reader sets it — through the settings action — rather than
    # written onto the jar unsigned, which the signed reader refuses.
    patch settings_url, params: { locale: "es" }
    # The apply runs in Spanish too, so the history under test is the one a Spanish
    # reader is really given rather than one this test assembled by hand.
    post apply_universe_draft_url(universe_slug: @universe.slug, id: target)

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    history = css_select(".draft-history").first.text.squish
    assert_match(/Aplicado/, history)
    assert_match(/1 cambio recordado ya es visible/, history)
    assert_select ".draft-change-outcome", text: "Visible"
  end

  test "the apply and discard controls are offered only while the draft is open" do
    open = draft_with(remember_create_payload)
    history = draft_with(remember_create_payload("Already applied"), closed: "applied")

    get universe_draft_url(universe_slug: @universe.slug, id: open)
    assert_select "form[action=?]", apply_universe_draft_path(universe_slug: @universe.slug, id: open), count: 1
    assert_select "form[action=?]", discard_universe_draft_path(universe_slug: @universe.slug, id: open), count: 1

    get universe_draft_url(universe_slug: @universe.slug, id: history)
    assert_select "form[action=?]", apply_universe_draft_path(universe_slug: @universe.slug, id: history), count: 0
    assert_select "form[action=?]", discard_universe_draft_path(universe_slug: @universe.slug, id: history), count: 0
  end

  # Submitting for review
  #
  # The third control on this page, and the one the universe's mode decides: a
  # `wikipedia` universe applies the draft here and now, a `github` one hands it to
  # a reviewer. What is asserted here is both halves of that — the rows a `github`
  # universe has instead, and the fact that the **actions** refuse the other mode's
  # answer rather than only the buttons being absent. A control hidden in the view
  # and a POST the server honours are two different things, and only the second one
  # is a rule.

  test "a github universe offers the handover instead of the apply, with a message field" do
    @universe.update!(collaboration_mode: "github")
    draft = draft_with(remember_create_payload)

    get universe_draft_url(universe_slug: @universe.slug, id: draft)

    assert_response :success
    assert_select "form[action=?]", submit_universe_draft_path(universe_slug: @universe.slug, id: draft), count: 1
    assert_select "textarea[name=?]", "review_request[submission_message]", count: 1
    # The apply is gone rather than merely disabled, and Discard stays: throwing
    # your own work away needs no reviewer and no mode.
    assert_select "form[action=?]", apply_universe_draft_path(universe_slug: @universe.slug, id: draft), count: 0
    assert_select "form[action=?]", discard_universe_draft_path(universe_slug: @universe.slug, id: draft), count: 1
  end

  test "submitting hands the draft over, stores the author's message, and writes nothing" do
    @universe.update!(collaboration_mode: "github")
    draft = draft_with(remember_create_payload)

    assert_no_difference -> { Character.count } do
      post submit_universe_draft_url(universe_slug: @universe.slug, id: draft),
        params: { review_request: { submission_message: "This is the second attempt" } }
    end

    assert_redirected_to universe_draft_url(universe_slug: @universe.slug, id: draft)
    assert_equal I18n.t("drafts.flash.submitted"), flash[:notice]
    # Both halves of the handover, or neither: the row and the status are what make
    # this a submission rather than a rename.
    request_record = draft.reload.pending_review_request
    assert_predicate draft, :submitted?
    assert_predicate request_record, :pending?
    assert_equal @user, request_record.submitted_by
    assert_equal "This is the second attempt", request_record.submission_message
  end

  test "a submission message is optional and a blank one is stored as nothing" do
    @universe.update!(collaboration_mode: "github")
    draft = draft_with(remember_create_payload)

    post submit_universe_draft_url(universe_slug: @universe.slug, id: draft),
      params: { review_request: { submission_message: "   " } }

    assert_predicate draft.reload, :submitted?
    # Not `""`, which would read back on the reviewer's page as something the
    # author wrote. This is `review_notes`' rule applied to the other column.
    assert_nil draft.pending_review_request.submission_message
  end

  test "a github universe refuses the author's own apply rather than doing it" do
    @universe.update!(collaboration_mode: "github")
    draft = draft_with(remember_create_payload)

    assert_no_difference -> { Character.count } do
      post apply_universe_draft_url(universe_slug: @universe.slug, id: draft)
    end

    assert_redirected_to universe_draft_url(universe_slug: @universe.slug, id: draft)
    assert_equal I18n.t("drafts.flash.wrong_mode"), flash[:alert]
    assert_predicate draft.reload, :draft?, "a refused apply must leave the draft exactly as it was"
    assert_nil draft.pending_review_request
  end

  test "a universe with no reviewer refuses a submission rather than handing it over" do
    @universe.update!(collaboration_mode: "wikipedia")
    draft = draft_with(remember_create_payload)

    post submit_universe_draft_url(universe_slug: @universe.slug, id: draft)

    assert_redirected_to universe_draft_url(universe_slug: @universe.slug, id: draft)
    assert_equal I18n.t("drafts.flash.wrong_mode"), flash[:alert]
    assert_predicate draft.reload, :draft?
    assert_empty draft.review_requests
  end

  test "a draft that is already with a reviewer cannot be submitted twice" do
    @universe.update!(collaboration_mode: "github")
    draft = draft_with(remember_create_payload)
    submitted = draft.submit!

    assert_no_difference -> { ReviewRequest.count } do
      post submit_universe_draft_url(universe_slug: @universe.slug, id: draft)
    end

    # Its own reason rather than the closed-draft one: this draft is very much
    # still open, and "already applied or discarded" would be a wrong answer for it.
    assert_equal I18n.t("drafts.flash.waiting_for_review"), flash[:alert]
    assert_equal [ submitted ], draft.reload.review_requests.to_a
  end

  test "another author's draft cannot be submitted" do
    @universe.update!(collaboration_mode: "github")
    theirs = Draft.create!(user: users(:user_two), universe: @universe)
    theirs.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Theirs", "universe_id" => @universe.id })

    post submit_universe_draft_url(universe_slug: @universe.slug, id: theirs)

    assert_response :not_found
    assert_predicate theirs.reload, :draft?
    assert_empty theirs.review_requests
  end

  test "a submission carrying a change the applier cannot read is still submittable" do
    # The same reasoning that keeps a damaged draft rejectable: a submission does
    # not interpret a remembered change, so refusing it here would leave the author
    # with a draft only **Discard** can clear and the reviewer with nothing to say
    # about it. The damage is still reported on the page.
    @universe.update!(collaboration_mode: "github")
    draft = draft_with(remember_create_payload("Unreadable", "Character",
      { "universe_id" => @universe.id }, extra: { "wibble" => 1 }))

    post submit_universe_draft_url(universe_slug: @universe.slug, id: draft)

    assert_redirected_to universe_draft_url(universe_slug: @universe.slug, id: draft)
    assert_predicate draft.reload, :submitted?
    assert_predicate draft.pending_review_request, :pending?

    # And the page behind the redirect still says what cannot be read, so the
    # reviewer finds out from the submission rather than from a failed approval.
    follow_redirect!
    assert_select ".draft-damaged", text: /wibble/
  end

  test "discarding a submitted draft withdraws the submission with it" do
    # Otherwise the reviewer's queue keeps waiting on work the author has thrown
    # away, and approving it would still write the changes: `DraftApplier` asks
    # whether a draft is open nowhere.
    @universe.update!(collaboration_mode: "github")
    draft = draft_with(remember_create_payload)
    submitted = draft.submit!

    post discard_universe_draft_url(universe_slug: @universe.slug, id: draft)

    assert_redirected_to universe_drafts_url(universe_slug: @universe.slug)
    assert_predicate draft.reload, :discarded?
    assert_predicate submitted.reload, :withdrawn?
    # It is no longer waiting on anybody, which is what a withdrawal means, and it
    # is nobody's decision, so it carries no reviewer.
    assert_nil draft.pending_review_request
    assert_not_includes ReviewRequest.pending, submitted
    assert_not_predicate submitted, :decided?
    assert_nil submitted.reviewed_by
    # And the draft still says when it stopped being actionable, which is the same
    # `closed_at` an ordinary discard writes.
    assert_not_nil draft.closed_at
  end

  test "an author reads where their own submission stands, and the reviewer's reason with it" do
    # The author's side is the half that was missing: a rejection's notes exist to
    # tell the author why, and a `github` draft can sit for days. A rejected draft
    # says "Draft" again, so the status of the *submission* can only come from the
    # request.
    @universe.update!(collaboration_mode: "github")
    draft = draft_with(remember_create_payload)
    submitted = draft.submit!(message: "This is the second attempt")

    get universe_draft_url(universe_slug: @universe.slug, id: draft)
    assert_select ".draft-submission-status .badge", text: "Waiting"
    assert_select ".draft-submission-state", text: /Waiting for a reviewer/
    assert_select ".draft-submission-message", text: /This is the second attempt/

    submitted.reject!(users(:user_two), notes: "The name is the old one")

    get universe_draft_url(universe_slug: @universe.slug, id: draft)
    # The badge is the request's own status, not the draft's: the draft says "Draft"
    # again and the reason it came back is the fact the author came to read.
    assert_select ".draft-submission-status .badge", text: "Rejected"
    assert_select ".draft-submission-state", text: /Rejected by User Two/
    assert_select ".draft-submission-notes", text: /The name is the old one/
    # And the author can submit it again, because it is their working work.
    assert_select "form[action=?]", submit_universe_draft_path(universe_slug: @universe.slug, id: draft), count: 1
  end

  test "a wikipedia draft's page says nothing about a submission it never made" do
    draft = draft_with(remember_create_payload)

    get universe_draft_url(universe_slug: @universe.slug, id: draft)

    assert_response :success
    assert_select ".draft-submission", count: 0
    assert_select ".draft-submission-status", count: 0
  end

  test "the handover and its status are rendered in Spanish as well as English" do
    # Every string on this page is chosen by the mode, so the mode branch has two sets
    # of words behind it and the key sets being equal — `translations_test.rb`'s job —
    # cannot see an interpolation that only renders wrong in the second language.
    @universe.update!(collaboration_mode: "github")
    draft = draft_with(remember_create_payload)
    patch settings_url, params: { locale: "es" }

    get universe_draft_url(universe_slug: @universe.slug, id: draft)

    assert_response :success
    assert_select ".draft-workflow-guide", text: /Entrega el borrador a quien lo revise/
    assert_select ".draft-submission", text: /Enviar este borrador a revisión/
    assert_select ".draft-submission", text: /Al enviar no se escribe nada/

    draft.submit!(message: "Es el segundo intento")

    get universe_draft_url(universe_slug: @universe.slug, id: draft)

    assert_select ".draft-submission-status .badge", text: "Esperando"
    # The author's own sentence and the reviewer's reason are both read on this page,
    # and a rejection's notes are the one that says why.
    assert_select ".draft-submission-message", text: /Es el segundo intento/
    draft.pending_review_request.reject!(users(:user_two), notes: "El nombre es el antiguo")

    get universe_draft_url(universe_slug: @universe.slug, id: draft)

    assert_select ".draft-submission-status .badge", text: "Rechazado"
    assert_select ".draft-submission-notes", text: /El nombre es el antiguo/
  end

  # Applying
  #
  # The live mutation path is the point: the same services, the same model
  # validations, the same soft delete. A test that asserted only "the record
  # changed" would pass against a plain `update_columns`, which is exactly the
  # applier ADR 0019 refuses.

  test "applying writes a create, an update, and a delete through the live path" do
    removed = locations(:location_one)
    target = draft_with(
      remember_create_payload,
      remember_update_payload("Renamed by a draft"),
      remember_delete_payload(removed)
    )

    post apply_universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_redirected_to universe_draft_url(universe_slug: @universe.slug, id: target)
    assert_equal I18n.t("drafts.flash.applied", count: 3), flash[:notice]
    created = Character.find_by(name: "Remembered create")
    assert created.present?, "a remembered create must be written by the apply"
    assert_equal @character.reload.name, "Renamed by a draft"
    assert_predicate removed.reload, :deleted?
    assert_predicate target.reload, :applied?
  end

  test "a created record lands in the ordered collection the live path would place it in" do
    # A Section is story-scoped, hierarchical, and positioned, so a plain `save`
    # would write it with the column default of 0 and leave it inside somebody
    # else's sibling group. `PositionedResourceOrder` is what makes it the last
    # child of its parent.
    section = draft_with(remember_create_payload("A remembered section", "Section",
      { "story_id" => @story.id, "parent_id" => sections(:section_one).id }))
    siblings = sections(:section_one).children.reorder(:position, :id).to_a

    post apply_universe_draft_url(universe_slug: @universe.slug, id: section)

    written = Section.find_by(name: "A remembered section")
    assert written.present?, "the create must be written"
    assert_equal sections(:section_one).id, written.parent_id
    # Appended after the one sibling that was already there, and the group is
    # renumbered so it stays contiguous — which is what the ordering service does
    # and what a plain `save` with the column default of 0 would not.
    assert_equal siblings.size, written.position
    assert_equal (0...siblings.size + 1).to_a, sections(:section_one).children.reorder(:position, :id).pluck(:position)
    assert_equal siblings.map(&:id) + [ written.id ], sections(:section_one).children.reorder(:position, :id).pluck(:id)
  end

  test "a story-scoped create is placed through the story the payload names" do
    other_story = stories(:story_alt)
    scene = draft_with(remember_create_payload("A remembered scene", "Scene", { "story_id" => other_story.id }))

    post apply_universe_draft_url(universe_slug: @universe.slug, id: scene)

    written = Scene.find_by(name: "A remembered scene")
    assert written.present?
    assert_equal other_story, written.story
    # A Scene's narrative order is a flat sequence inside its own story, so the
    # scene joins the end of that story's sequence and is numbered against it —
    # not against the story the draft's page happens to be sitting in.
    assert_equal other_story.scenes.count - 1, written.position
    assert_equal (0...other_story.scenes.count).to_a, other_story.scenes.reorder(:position, :id).pluck(:position)
  end

  # Resolving a conflict
  #
  # A conflict stops the apply: nothing is written until every conflict has an
  # answer, so the page and the applier are two halves of one decision. What the
  # author is *shown* is asserted here; what an answer *does* to a record is
  # `test/services/draft_applier_test.rb`.

  test "an apply that finds a conflict shows it instead of writing" do
    moved = draft_with(remember_update_payload("Renamed by a draft"), remember_create_payload)
    change = moved.draft_changes.first
    # Somebody else renamed the same record after the change was remembered,
    # which is what `base_version` exists to notice.
    @character.update!(name: "Renamed by somebody else", description: "Also changed by somebody else")
    assert VersionStamp.changed?(@character, change.base_version)

    post apply_universe_draft_url(universe_slug: @universe.slug, id: moved)

    assert_response :unprocessable_content
    assert_select "h1", text: "Conflicts to resolve"
    assert_select "form[action=?]", apply_universe_draft_path(universe_slug: @universe.slug, id: moved), count: 1
    assert_select ".draft-conflict", count: 1
    # The record, its type, and the state that put the row here.
    assert_select ".draft-conflict .entity-title a[href=?]", @character.search_url, count: 1
    assert_select ".draft-conflict-kind", text: "Character"
    assert_select ".draft-conflict-state", text: "Changed elsewhere"
    # Both halves of the choice, so the buttons can be evaluated rather than
    # pressed at random. They print the same field under the same label, which is
    # what makes them a comparison instead of two sentences about a record.
    assert_select ".draft-conflict-mine", text: /Renamed by a draft/
    assert_select ".draft-conflict-theirs", text: /Renamed by somebody else/
    assert_select ".draft-conflict-choice", text: /Choosing theirs keeps what is there now/
    assert_select "button[name=?][value=?]", "resolutions[#{change.id}]", "theirs", count: 1
    assert_select "button[name=?][value=?]", "resolutions[#{change.id}]", "mine", count: 1
    assert_select ".draft-conflict button", text: "Apply theirs"
    assert_select ".draft-conflict button", text: "Apply mine"
    # Nothing is written, and the draft is still applyable: the answers are what
    # the write was waiting for. The rest of the draft waits with it, because a
    # half-applied draft and a remembered create are the duplicate-write hazard
    # ADR 0021 closes.
    assert_equal "Renamed by somebody else", @character.reload.name
    assert_nil Character.find_by(name: "Remembered create")
    assert_predicate moved.reload, :draft?
  end

  test "an update onto a record somebody deleted is shown as a conflict, without a link to it" do
    draft = draft_with(remember_update_payload("Renamed by a draft"))
    @character.soft_delete

    post apply_universe_draft_url(universe_slug: @universe.slug, id: draft)

    assert_response :unprocessable_content
    assert_select ".draft-conflict", count: 1
    assert_select ".draft-conflict-state", text: "Deleted elsewhere"
    assert_select ".draft-conflict .entity-title a", count: 0
    assert_select ".draft-conflict-theirs", text: /the record stays deleted/
    assert_select ".draft-conflict-theirs", text: /Somebody deleted this record/
    assert_select ".draft-conflict-choice", text: /brings the record back/
    assert_predicate @character.reload, :deleted?, "showing a conflict must not write anything"
    assert_predicate draft.reload, :draft?
  end

  test "answering a conflict with theirs keeps the record and drops the change" do
    moved = draft_with(remember_update_payload("Renamed by a draft"), remember_create_payload)
    change = moved.draft_changes.first
    @character.update!(name: "Renamed by somebody else", description: "Also changed by somebody else")

    post apply_universe_draft_url(universe_slug: @universe.slug, id: moved),
      params: { resolutions: { change.id => "theirs" } }

    assert_redirected_to universe_draft_url(universe_slug: @universe.slug, id: moved)
    # A change dropped on purpose is not a change that failed: the progress
    # sentence still counts what was written, and the choice gets its own.
    assert_equal [
      I18n.t("drafts.flash.applied", count: 1),
      I18n.t("drafts.flash.kept_theirs", count: 1)
    ].join(" "), flash[:notice]
    assert_equal "Renamed by somebody else", @character.reload.name,
      "theirs keeps the record as the other editor left it"
    assert Character.find_by(name: "Remembered create").present?,
      "the rest of the draft is still written: one decision does not block the others"
    assert_predicate moved.reload, :applied?
  end

  # A change the applier cannot read at all
  #
  # `DraftIntegrity`'s rule is asserted in `test/services/draft_integrity_test.rb`.
  # What only this path can show is the *answer*: the author's own page, refusing in
  # words, with nothing written and the draft still open — rather than a 404 that reads
  # as "this draft does not exist" for a draft the author is looking at.

  test "a change the applier cannot read refuses the apply in words and writes nothing" do
    damaged = draft_with(remember_create_payload("A remembered create", "Character",
      { "universe_id" => @universe.id }, extra: { "wibble" => 1 }))

    post apply_universe_draft_url(universe_slug: @universe.slug, id: damaged)

    assert_response :unprocessable_content
    assert_select ".draft-damaged", text: /cannot be applied as it stands/
    assert_select ".draft-damaged", text: /wibble/
    assert_select ".draft-change", { count: 1 }, "the change is still listed: it is still what the author asked for"
    assert_nil Character.find_by(name: "A remembered create")
    assert_predicate damaged.reload, :draft?, "a refused run leaves the author's way out — Discard — untouched"
  end

  test "a create naming a record type this application does not have is refused by name" do
    damaged = draft_with(remember_create_payload)
    damaged.draft_changes.sole.update_column(:record_type, "RetiredModel")

    post apply_universe_draft_url(universe_slug: @universe.slug, id: damaged)

    assert_response :unprocessable_content
    assert_select ".draft-damaged", text: /RetiredModel/
    assert_predicate damaged.reload, :draft?
  end

  test "the draft's own page says what cannot be read before the author presses anything" do
    damaged = draft_with(remember_create_payload("A remembered create", "Character",
      { "universe_id" => @universe.id }, extra: { "wibble" => 1 }))

    get universe_draft_url(universe_slug: @universe.slug, id: damaged)

    assert_response :success
    assert_select ".draft-damaged", text: /wibble/
  end

  test "answering a conflict with mine writes the remembered fields over what is there" do
    moved = draft_with(remember_update_payload("Renamed by a draft"), remember_create_payload)
    change = moved.draft_changes.first
    @character.update!(name: "Renamed by somebody else", description: "Also changed by somebody else")

    post apply_universe_draft_url(universe_slug: @universe.slug, id: moved),
      params: { resolutions: { change.id => "mine" } }

    assert_equal I18n.t("drafts.flash.applied", count: 2), flash[:notice]
    assert_equal "Renamed by a draft", @character.reload.name
    # "Overwrite with my change" is the change's own payload, not the whole row:
    # a conflict is per record, and a field the author never submitted is still
    # the other editor's.
    assert_equal "Also changed by somebody else", @character.description
    assert_predicate moved.reload, :applied?
  end

  test "an update onto a deleted record, answered with mine, brings the record back with the change" do
    draft = draft_with(remember_update_payload("Renamed by a draft"), remember_create_payload)
    change = draft.draft_changes.first
    @character.soft_delete

    post apply_universe_draft_url(universe_slug: @universe.slug, id: draft),
      params: { resolutions: { change.id => "mine" } }

    # The restored update and the remembered create are both written, which is
    # what makes the answer atomic rather than a restore that then waited.
    assert_equal I18n.t("drafts.flash.applied", count: 2), flash[:notice]
    assert_not_predicate @character.reload, :deleted?
    assert_equal "Renamed by a draft", @character.name
    assert Character.find_by(name: "Remembered create").present?
    assert_predicate draft.reload, :applied?
  end

  test "a delete whose record has changed, answered with mine, removes it anyway" do
    removed = locations(:location_one)
    draft = draft_with(remember_delete_payload(removed))
    change = draft.draft_changes.first
    removed.update!(name: "Renamed by somebody else")

    post apply_universe_draft_url(universe_slug: @universe.slug, id: draft),
      params: { resolutions: { change.id => "mine" } }

    assert_equal I18n.t("drafts.flash.applied", count: 1), flash[:notice]
    assert_predicate removed.reload, :deleted?
    assert_predicate draft.reload, :applied?
  end

  test "answers already given are carried so the remaining conflicts can still be chosen" do
    other = characters(:character_two)
    draft = draft_with(
      remember_update_payload("Renamed by a draft"),
      remember_update_payload("Renamed too", other),
      remember_create_payload
    )
    first, second = draft.draft_changes.to_a
    @character.update!(description: "Changed by somebody else")
    other.update!(description: "Changed by somebody else too")

    post apply_universe_draft_url(universe_slug: @universe.slug, id: draft),
      params: { resolutions: { first.id => "mine" } }

    assert_response :unprocessable_content
    assert_select ".draft-conflict", count: 2
    # The answer already given is a hidden field, rendered before that row's own
    # buttons, so re-pressing the row overrides it rather than losing it.
    assert_select "input[type=hidden][name=?][value=?]", "resolutions[#{first.id}]", "mine", count: 1
    assert_select "input[type=hidden][name=?]", "resolutions[#{second.id}]", count: 0
    assert_equal "Character one", @character.reload.name,
      "nothing is written while one conflict is still unanswered"
    assert_predicate draft.reload, :draft?

    post apply_universe_draft_url(universe_slug: @universe.slug, id: draft),
      params: { resolutions: { first.id => "mine", second.id => "theirs" } }

    assert_response :see_other
    assert_equal "Renamed by a draft", @character.reload.name
    assert_equal "Character two", other.reload.name
    assert Character.find_by(name: "Remembered create").present?
    assert_predicate draft.reload, :applied?
  end

  test "an answer that is not one of the two the page offers is ignored" do
    draft = draft_with(remember_update_payload("Renamed by a draft"))
    change = draft.draft_changes.first
    @character.update!(description: "Changed by somebody else")

    post apply_universe_draft_url(universe_slug: @universe.slug, id: draft),
      params: { resolutions: { change.id => "perhaps" } }

    assert_response :unprocessable_content
    assert_equal "Character one", @character.reload.name
    assert_predicate draft.reload, :draft?
  end

  test "a change the universe refuses is reported rather than half-written" do
    # The remembering path does not validate (ADR 0020), so a create the live path
    # would refuse is remembered and refused here, at the point where the model's
    # own validations are authoritative.
    refused = draft_with(remember_create_payload(""))

    post apply_universe_draft_url(universe_slug: @universe.slug, id: refused)

    assert_equal I18n.t("drafts.flash.partially_applied", applied: 0, skipped: 1), flash[:notice]
    assert_equal 0, Character.where(name: "").count
    assert_predicate refused.reload, :applied?
  end

  test "a change whose record has been deleted since is reported rather than written" do
    gone = draft_with(remember_delete_payload(@character))
    @character.soft_delete

    post apply_universe_draft_url(universe_slug: @universe.slug, id: gone)

    assert_equal I18n.t("drafts.flash.partially_applied", applied: 0, skipped: 1), flash[:notice]
    assert_predicate gone.reload, :applied?
  end

  test "a create that cannot be placed in this universe is reported rather than written across it" do
    # The scope column is stored data read back later, and it is resolved rather
    # than trusted: a story belonging to another universe is not a scope here.
    foreign = draft_with(remember_create_payload("Out of place", "Character",
      { "universe_id" => universes(:universe_two).id }))

    post apply_universe_draft_url(universe_slug: @universe.slug, id: foreign)

    assert_equal I18n.t("drafts.flash.partially_applied", applied: 0, skipped: 1), flash[:notice]
    assert_nil universes(:universe_two).characters.find_by(name: "Out of place"),
      "a create must never be written into a universe the request did not authorize"
  end

  test "applying a draft twice is refused rather than writing a second copy" do
    target = draft_with(remember_create_payload)

    post apply_universe_draft_url(universe_slug: @universe.slug, id: target)
    assert_response :see_other

    assert_no_difference -> { Character.count } do
      post apply_universe_draft_url(universe_slug: @universe.slug, id: target)
    end

    assert_redirected_to universe_draft_url(universe_slug: @universe.slug, id: target)
    assert_equal I18n.t("drafts.flash.closed"), flash[:alert]
    assert_equal 1, Character.where(name: "Remembered create").count
  end

  test "a discarded draft cannot be applied afterwards" do
    target = draft_with(remember_create_payload)

    post discard_universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_no_difference -> { Character.count } do
      post apply_universe_draft_url(universe_slug: @universe.slug, id: target)
    end

    assert_equal I18n.t("drafts.flash.closed"), flash[:alert]
  end

  # Discarding

  test "discarding closes the draft and keeps the changes it remembered" do
    target = draft_with(remember_create_payload)

    post discard_universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_redirected_to universe_drafts_url(universe_slug: @universe.slug)
    assert_equal I18n.t("drafts.flash.discarded"), flash[:notice]
    assert_predicate target.reload, :discarded?
    # A remembered change is append-only, so rejecting the draft moves the draft's
    # status rather than deleting what it said. The draft's page still lists it.
    assert_equal 1, target.draft_changes.count

    get universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_response :success
    assert_select ".draft-change", count: 1
  end

  test "discarding a draft that is already applied changes nothing" do
    target = draft_with(remember_create_payload, closed: "applied")

    post discard_universe_draft_url(universe_slug: @universe.slug, id: target)

    assert_equal I18n.t("drafts.flash.closed"), flash[:alert]
    assert_predicate target.reload, :applied?
  end

  test "another author's draft cannot be applied or discarded" do
    theirs = Draft.create!(user: users(:user_two), universe: @universe)
    theirs.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Theirs", "universe_id" => @universe.id })

    assert_no_difference -> { Character.count } do
      post apply_universe_draft_url(universe_slug: @universe.slug, id: theirs)
      post discard_universe_draft_url(universe_slug: @universe.slug, id: theirs)
    end

    assert_response :not_found
    assert_predicate theirs.reload, :draft?
  end

  # The page has to be reachable. An editor who is told their change was
  # remembered and cannot then find it has no way to apply or throw it away, so
  # the right sidebar offers it wherever a draft can exist.

  test "the sidebar offers pending changes only where a draft can exist" do
    get universe_url(@universe)
    assert_select "aside.right-sidebar a[href=?]", universe_drafts_path(universe_slug: @universe.slug),
      { count: 0 }, "a direct universe never opens a draft, so the link would lead nowhere"

    @universe.update!(collaboration_mode: "wikipedia")

    get universe_url(@universe)
    assert_select "aside.right-sidebar a[href=?]", universe_drafts_path(universe_slug: @universe.slug), count: 1

    sign_out
    get universe_url(@universe)
    assert_select "aside.right-sidebar a[href=?]", universe_drafts_path(universe_slug: @universe.slug),
      { count: 0 }, "a draft belongs to a person, and a visitor has none"
  end

  private
    def draft_with(*changes, status: "draft", closed: nil)
      # A closed draft has to say when it stopped being actionable, which is what
      # `DraftsController#discard` and the applier both write. A test that builds
      # one by hand closes it the same way, rather than leaving the model to infer
      # the moment from `updated_at`.
      Draft.create!(user: @user, universe: @universe,
        status: closed || status, closed_at: closed ? Time.current : nil).tap do |draft|
        changes.each { |change| draft.draft_changes.create!(change) }
      end
    end

    # The remembered attributes a controller would have submitted: the values, plus
    # the one column that places the record in its scope, which
    # `draft_mutation_test.rb` asserts for all twenty controllers.
    def remember_create_payload(name = "Remembered create", record_type = "Character",
      scope = { "universe_id" => @universe.id }, extra: {})
      { action: "create", record_type: record_type, record_id: nil, base_version: nil,
        payload: scope.merge("name" => name).merge(extra) }
    end

    def remember_update_payload(name, record = @character)
      { action: "update", record_type: record.class.name, record_id: record.id,
        base_version: DraftChange.capture_base_version(record), payload: { "name" => name } }
    end

    def remember_delete_payload(record)
      { action: "delete", record_type: record.class.name, record_id: record.id,
        base_version: DraftChange.capture_base_version(record), payload: nil }
    end
end
