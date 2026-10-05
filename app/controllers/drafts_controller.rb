# One author's remembered changes for one universe: the list of them, one draft
# in detail, and the two things an author can do about a draft.
#
# **Every action requires a signed-in user.** A draft belongs to a person, and a
# draft with no owner is not a thing this application can represent, so there is
# no guest-readable version of this page. A read is `read` access on the universe
# and a write is `write` access, which is what the shared
# `UniverseAuthorization` callback already decides from the action's name.
#
# **A draft is read as its own author's, inside the universe the request has
# already authorized.** `Draft` is deliberately not a content class (ADR 0019):
# somebody else's unfinished work is not something a universe publishes, so there
# is no CanCan rule to ask and the scope is the query itself. Another author's
# draft, a draft in another universe, and a draft that does not exist are one
# indistinguishable **404** — the same answer `RecordTarget` gives, because a
# pending change is not a permission decision and must not be an oracle for what
# other people are working on.
#
# This is the fifth page shape rather than a record's `show`: it is a workspace
# page for the reader's own pending work, and unlike a details page it carries
# mutation controls, because acting on a draft *is* the page. The controls are
# shown only while the draft can still be acted on, which is `Draft#open?` read
# once here rather than re-derived in the view.
#
# **Which of the two ways out the page offers is the universe's collaboration
# mode.** A `wikipedia` universe has one author and no reviewer, so its primary
# control is **Apply changes**, which writes the remembered changes live. A
# `github` universe has a reviewer, so the same control becomes **Submit for
# review**, which hands the draft over instead — with a field for the author's own
# sentence about it. **Discard** is the third control and belongs to both: throwing
# away your own pending work needs no reviewer and no mode.
#
# The mode is enforced on the actions as well as on the buttons, which is the half
# that matters: `apply` refuses a `github` universe and `submit` refuses anything
# else, so a POST that skipped the page is answered with the same sentence the page
# would have shown rather than doing the other mode's work.
#
# `apply` is the one action that can answer with a page of its own: when it finds
# conflicts it renders them instead of writing, because the author's answer is
# what the write is waiting for. That page is `drafts/conflicts`, it is a `422`
# (this is an apply being refused until it is told what to do), and it posts back
# to the same action — so `apply` is reached twice on that journey, once to show
# the question and once with the answers.
#
# **A draft the applier cannot read is refused before it is run, in words rather than as
# a 404.** `DraftIntegrity` is asked first, because an unreadable remembered change is not
# a conflict — there is nothing to choose between — and letting the applier raise would
# answer "this draft does not exist" for a draft that is sitting right there. See
# `DraftIntegrity` and ADR 0021, whose decision to *refuse* such a change is unchanged:
# only the shape of the answer is.
class DraftsController < ApplicationController
  include AppliesDrafts

  before_action :set_draft, only: %i[ show apply submit discard ]
  before_action :set_damaged, only: %i[ show apply ]

  # GET /u/:universe_slug/drafts
  #
  # The reader's own drafts in this universe, with the one that can still be
  # acted on first: an applied or discarded draft is history, and history sorted
  # above the pending work would push the draft the reader came here for out of
  # the list. The sort is in Ruby because the whole list is one person's drafts in
  # one universe — a few rows at most — and a second `ORDER BY` would be a
  # cheaper way to say the same thing badly.
  def index
    @drafts = drafts.sort_by { |draft| [ draft.open? ? 0 : 1, -draft.id ] }
  end

  # GET /u/:universe_slug/drafts/:id
  #
  # Every change the draft remembers, in the order they were remembered, each
  # beside what the apply that wrote it recorded. An open draft has no outcomes
  # yet, so the page states what each change *says* and nothing more; a closed one
  # says both, because the answer is stored rather than inferred (ADR 0024).
  #
  # The outcomes are preloaded here rather than resolved per row, which is the one
  # query the page adds over the changes themselves.
  def show
    @draft.draft_changes.includes(:outcome)
    # The submission this page describes, which is the **newest** one rather than the
    # pending one: a rejected handover leaves the draft back at `draft`, so the row
    # that still carries the reviewer's reason is history from the draft's point of
    # view and exactly what the author came to read. Nil in every draft of a
    # `wikipedia` universe, which is where the page renders nothing.
    @review_request = @draft.review_requests.includes(:reviewed_by).order(:id).last
  end

  # POST /u/:universe_slug/drafts/:id/apply
  #
  # Writes the changes through the live mutation path and closes the draft. See
  # `DraftApplier` for why the draft is closed even when a change is skipped.
  #
  # **A `github` universe refuses this action**, because that mode exists precisely
  # so that a draft does not become live on the author's say-so: `submit` is that
  # mode's answer, and a reviewer's approval is the only apply it allows. The check
  # is first because it is the more fundamental of the two refusals — a draft in a
  # `github` universe may well be closed as well, and "this universe reviews drafts"
  # is the reason that matters.
  #
  # **A conflict stops the apply and is shown instead.** The detector is asked on
  # *this* request rather than remembered from the last one, so the conflicts the
  # author is asked about are the ones this apply would otherwise skip: a record
  # that moved while the page was open is a conflict they have not answered, and
  # the page comes back with it. Nothing is written until every conflict has an
  # answer, and the answers are not remembered either — they belong to this
  # request, which is why a failed apply leaves a draft that simply asks again.
  def apply
    return refuse_wrong_mode if Current.universe.github?
    return refuse_closed_draft unless @draft.open?
    return show_damaged if @damaged.damaged?

    conflicts = draft_conflicts(@draft)
    answers = submitted_answers

    return show_conflicts(conflicts, answers) unless answered_all?(conflicts, answers)

    result = DraftApplier.new(@draft, answers: answers).apply

    redirect_to universe_draft_path(universe_slug: Current.universe.slug, id: @draft),
      notice: draft_apply_notice(result), status: :see_other
  end

  # POST /u/:universe_slug/drafts/:id/submit
  #
  # Hands the draft to a reviewer instead of applying it, which is what a `github`
  # universe does and a `wikipedia` one does not. `Draft#submit!` writes both halves
  # — the review request and the draft's `submitted` status — in one transaction, so
  # this action has one job left: refuse the two states that are not a submission.
  #
  # **A draft that is not a working draft cannot be submitted.** A `submitted` one is
  # already with a reviewer, and the partial unique index would refuse the second row
  # anyway; an applied or discarded one has nothing left to hand over. Both are the
  # same answer as `apply` gives a closed draft, so the page says so rather than
  # raising out of the model — but the reason names which of the two it was, because
  # "already waiting for a reviewer" and "already applied" are different facts about
  # the same button.
  #
  # **Nothing about the draft's changes is read here**, for `ReviewRequestsController#reject`'s
  # reason: a submission does not interpret a remembered change, so one the applier
  # could not read is still submittable and still rejectable. Refusing to submit it
  # would leave the author with a damaged draft that only **Discard** can clear, and
  # refusing to reject it would leave the reviewer with nothing they can do.
  #
  # **The message is optional and a blank one is stored as nothing**, in the model
  # rather than here: a `github` handover often needs no explanation, and an empty
  # string would read back on the reviewer's page as something the author wrote.
  def submit
    return refuse_wrong_mode unless Current.universe.github?
    return refuse_closed_draft unless @draft.draft?

    @draft.submit!(message: submission_message)

    redirect_to universe_draft_path(universe_slug: Current.universe.slug, id: @draft),
      notice: t("drafts.flash.submitted"), status: :see_other
  end

  # POST /u/:universe_slug/drafts/:id/discard
  #
  # Rejecting a draft moves the **draft's** status rather than deleting anything:
  # a remembered change is append-only, so what the author decided about it is
  # recorded on the draft and the change itself keeps saying what it said.
  #
  # `closed_at` is written here for the same reason the applier writes its own:
  # a draft that can no longer be acted on has to say when it stopped being
  # actionable, or its history would have to read the moment off `updated_at`.
  #
  # **Discarding a draft that is with a reviewer withdraws the submission too**, in
  # one transaction (`ReviewRequest#withdraw!`). Otherwise the reviewer's queue keeps
  # waiting on work the author has thrown away, and approving it would still write
  # the changes — `DraftApplier` asks whether a draft is open nowhere, so a discarded
  # draft is applied like any other. A withdrawal is the author's own answer rather
  # than a reviewer's, so the request carries no reviewer: it is a queue row answered
  # by the absence of work, and it stays in the queue's history rather than being
  # hidden.
  def discard
    return refuse_closed_draft unless @draft.open?

    if (submission = @draft.pending_review_request)
      submission.withdraw!
    else
      @draft.update!(status: "discarded", closed_at: Time.current)
    end

    redirect_to universe_drafts_path(universe_slug: Current.universe.slug),
      notice: t("drafts.flash.discarded"), status: :see_other
  end

  private

    # What the author typed into the submission message, or nothing.
    #
    # It is read as a parameter rather than assigned, because there is no
    # `ReviewRequest` on this page yet — the row is created by the model's own
    # `submit!`, which is what writes the draft's status in the same transaction.
    # The shape check is `review_notes`' reason: a form field is a string, and
    # anything else that arrives is not one.
    def submission_message
      notes = params[:review_request]
      return nil unless notes.is_a?(ActionController::Parameters)

      notes.permit(:submission_message)[:submission_message].presence
    end
    def drafts
      Current.universe.drafts.where(user: Current.user)
    end

    # What the applier could not read, asked once and held for the page.
    #
    # It is set for `show` as well as `apply`, because the two are the same fact about
    # the draft: an author who can read "one of these changes names a record type this
    # application does not have" before pressing Apply is not told about it by a 404
    # afterwards, and the page behind the refusal renders the same notice from the same
    # object rather than re-deriving it.
    def set_damaged
      @damaged = DraftIntegrity.new(@draft)
    end

    # The refusal, as this page: the changes are still listed, and the notice says which
    # of them cannot be read. Nothing was written and the draft is still open, so the
    # author's own way out — Discard, which is the only control that can remove a change
    # it cannot interpret — is untouched.
    def show_damaged
      render :show, status: :unprocessable_content
    end

    def set_draft
      @draft = drafts.find(params.expect(:id))
    end

    # An applied or discarded draft is history. Applying it again would write a
    # remembered create a second time, so the answer is the draft's own page with
    # the reason rather than a silent no-op.
    #
    # **A submitted draft is refused with the same control and a different
    # sentence**, because it is the one state where the page still offers controls
    # and both of them would be refused: `apply` and `submit` are the other mode's
    # answer. Saying "already applied or discarded" would be a wrong reason for a
    # draft that is very much still open.
    def refuse_closed_draft
      redirect_to universe_draft_path(universe_slug: Current.universe.slug, id: @draft),
        alert: t(@draft.submitted? ? "drafts.flash.waiting_for_review" : "drafts.flash.closed"),
        status: :see_other
    end

    # **The mode belongs on the action, not only on the control.** A `github` universe
    # has a reviewer decide whether a draft becomes live, so an author cannot apply
    # it themselves; a `wikipedia` one has nobody to hand it to, so there is nothing
    # to submit. Hiding the wrong button is half the rule — the other half is that a
    # forged or stale POST is refused with the same sentence the page would have
    # shown, which is why both refusals share one key rather than composing a second.
    #
    # The answer is the draft's own page rather than a 404: the draft exists, the
    # reader is its author, and the page is where the right control is.
    def refuse_wrong_mode
      redirect_to universe_draft_path(universe_slug: Current.universe.slug, id: @draft),
        alert: t("drafts.flash.wrong_mode"), status: :see_other
    end
end
