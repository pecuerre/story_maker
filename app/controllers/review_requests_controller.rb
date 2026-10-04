# What a reviewer can do about somebody else's submitted draft.
#
# **This is the second half of a `github` universe's collaboration mode**, and the page
# shape is the drafts page read from the other side: an author opens their own pending
# work and decides about it, and an owner or admin opens what is waiting for a decision.
# The draft itself is not re-modelled here — the review request is the subject of these
# pages, and it points at the draft whose changes it is about.
#
# **Every action asks for `admin` on the universe**, through `UniverseAuthorization`,
# the same line memberships use. That is not a stronger version of the drafts page's
# `read`/`write` split, it is a different question: the drafts pages answer "may this
# person see and act on their own pending work", while these answer "may this person see
# what other people have asked to change here, and decide it". A queue a plain writer can
# read is a queue they have no business in, and the list is itself an answer — it names
# every author who has submitted something. `ReviewRequest` is deliberately not in
# `Ability::CONTENT_CLASS_NAMES` for the reason `Draft` is not: somebody's unfinished
# work under somebody else's decision is not something a universe publishes, and the
# content rules would answer `read` for a guest in a public universe.
#
# **The two decisions are the applier and the queue, not two copies of an apply.**
# `approve` runs the same `DraftConflictDetector`, renders the same conflict rows, and
# calls the same `DraftApplier` the author's own apply does — resolved answers, the same
# transaction, the same stored outcomes, and the same flash sentences, all of which come
# from `AppliesDrafts`. A second implementation would be a second answer to "what does
# approving do", and the two would drift on the first change to `DraftApplier` that one of
# them was not updated for.
#
# **What the reviewer's decision cannot do is decide twice.** A request that is already
# approved or rejected is history, and pressing Approve again would write the same
# remembered create a second time — the duplicate-write hazard [ADR
# 0021](docs/adr/0021-applying-a-draft-through-the-live-mutation-path.md) closes. Both
# actions therefore redirect to the request's own page with the reason, exactly as an
# author pressing **Apply** on an applied draft does.
#
# **A rejection is the one decision that is reversible**, because it is the one that
# hands the draft back: `ReviewRequest#reject!` moves the request and the draft's status
# in one transaction, so the author's edits are theirs again and the queue no longer
# waits. Approval closes the draft for good, because its changes are now live records.
class ReviewRequestsController < ApplicationController
  include AppliesDrafts

  # What the notes field shows, which is the request's own answer or the stored
  # decision's — a view may not read either of those without saying which one it
  # wants. `helper_method` is the way a controller hands one of its own readings to a
  # template; the same line `SearchesController` uses for its page number.
  helper_method :review_notes_field

  before_action :set_review_request, only: %i[ show approve reject ]
  # `reject` is here for the page it re-renders rather than for anything it decides: a
  # rejection never reads a remembered change, and this action is the one that leaves a
  # submission the reviewer cannot approve alone.
  before_action :set_damaged, only: %i[ show approve reject ]

  # GET /u/:universe_slug/review_requests
  #
  # The queue, with the decided submissions behind the waiting ones rather than beside
  # them: a reviewer comes here to decide something, and a decision sorted above a
  # pending submission would push the thing they came for down the page. The decided
  # rows are history rather than noise — they are where "who let this through" is
  # answered, and `ReviewRequest` validates a reviewer onto every one of them for
  # exactly that reason.
  #
  # The sort is in Ruby for the same reason the drafts list's is: this is one
  # universe's submissions, a few rows at most, and a second `ORDER BY` would be a
  # cheaper way to say the same thing badly.
  def index
    @review_requests = Current.universe.review_requests
      .includes(:draft, :submitted_by).order(:id)
      .sort_by { |request| [ request.pending? ? 0 : 1, -request.id ] }
  end

  # GET /u/:universe_slug/review_requests/:id
  #
  # Every change the submitted draft remembers, in the order they were remembered, each
  # row read through `drafts/_change` — the same partial, and therefore the same reading
  # of a remembered value, that the author reads on their own draft's page. A reviewer
  # cannot act on the draft itself: the two controls here answer about the submission,
  # and the draft's own page stays the author's.
  #
  # An open draft has no outcomes yet, so the rows say what each change *says* and
  # nothing more. Once approved, the rows carry the outcome the run stored, so this
  # page becomes the place a reviewer reads what their decision actually did (ADR 0024).
  def show
    draft.draft_changes.includes(:outcome)
  end

  # POST /u/:universe_slug/review_requests/:id/approve
  #
  # Writes the draft's changes through the live mutation path and closes the draft,
  # which is `DraftsController#apply` in full — including its two refusals, because a
  # reviewer answers the same two questions an author does.
  #
  # **A change the applier cannot read refuses the whole decision, in words.** That is
  # `DraftIntegrity`'s question and it is asked before the run, because the alternative
  # is a raise escaping as a 404 and a reviewer reading "this submission does not
  # exist" for a submission that is sitting in the queue in front of them.
  #
  # **A conflict stops the approval and is shown instead**, as a `422`, answering the
  # reviewer rather than the author — the same page shape, the same rows, and the same
  # two answers, posted back to this action.
  #
  # **The decision and the run are one transaction.** The applier closes the draft
  # inside its own, and the request's approval has to land in the same one: an approved
  # request over a draft that was not applied is a queue entry claiming a review that
  # never happened, and it is unreachable afterwards because the draft is closed.
  #
  # **An approval may carry a note, and it is optional.** The column is nullable for
  # exactly this reason: most approvals have nothing to explain, and a rejection is the
  # decision that has to. What the note is for is the author, so it travels with the
  # decision and is stored on it rather than on the draft — and it is kept through both
  # refusals below, because an approval is reached twice when a change has moved and the
  # reviewer should not write the same sentence again on the way in.
  def approve
    return refuse_decided_request unless @review_request.pending?

    @review_notes = review_notes

    return show_refusal if @damaged.damaged?

    conflicts = draft_conflicts(draft)
    answers = submitted_answers

    return show_conflicts(conflicts, answers, template: :conflicts) unless answered_all?(conflicts, answers)

    result = nil

    ApplicationRecord.transaction do
      result = DraftApplier.new(draft, answers: answers).apply
      @review_request.update!(status: "approved", reviewed_by: Current.user, review_notes: @review_notes)
    end

    redirect_to universe_review_request_path(universe_slug: Current.universe.slug, id: @review_request),
      notice: draft_apply_notice(result), status: :see_other
  end

  # POST /u/:universe_slug/review_requests/:id/reject
  #
  # Refuses the submission and hands the draft back. Notes are **required** — `ReviewRequest`
  # refuses a rejection without them — and a refusal re-renders this page with the
  # reason beside the field rather than redirecting, because a redirect would discard
  # what the reviewer typed, which is the rule every other form in the application
  # follows.
  #
  # **A blank note arrives as nil rather than an empty string**, which is what the
  # model's own validation asks about and what keeps `review_notes` from storing an
  # approval's empty box as if a reviewer had said something.
  #
  # Nothing about the draft's changes is read here: a rejection does not interpret a
  # remembered change, so a submission carrying one the applier could not read is still
  # rejectable, and refusing it must not be the reviewer's only option.
  def reject
    return refuse_decided_request unless @review_request.pending?

    return show_refusal unless @review_request.reject!(Current.user, notes: review_notes)

    redirect_to universe_review_request_path(universe_slug: Current.universe.slug, id: @review_request),
      notice: t("review_requests.flash.rejected"), status: :see_other
  end

  private
    def draft
      @review_request.draft
    end

    # Read through the universe the request has already authorized, so a submission in
    # another universe and a submission that does not exist are one answer.
    def set_review_request
      @review_request = Current.universe.review_requests.find(params.expect(:id))
    end

    # What the applier could not read, asked once and held for the page, for the same
    # reason and with the same shape as `DraftsController`'s: the page states the damage
    # and the decision refuses on it, and neither re-derives it.
    def set_damaged
      @damaged = DraftIntegrity.new(draft)
    end

    # Every refusal on this page re-renders it rather than redirecting: the changes
    # being read are still the ones the reviewer came for, and the errors belong to the
    # instance that carries them — a rejection without its required notes is a waiting
    # submission whose form still has its controls, and a draft the applier cannot read
    # is a submission that cannot be approved rather than one that has disappeared.
    def show_refusal
      render :show, status: :unprocessable_content
    end

    # A decision that has already been made is history, and re-running it would write a
    # remembered create a second time. The answer is the request's own page with the
    # reason, which is the shape `DraftsController#refuse_closed_draft` uses for the same
    # hazard on the author's side.
    def refuse_decided_request
      redirect_to universe_review_request_path(universe_slug: Current.universe.slug, id: @review_request),
        alert: t("review_requests.flash.decided"), status: :see_other
    end

    def review_notes
      notes = params[:review_request]
      return nil unless notes.is_a?(ActionController::Parameters)

      notes.permit(:review_notes)[:review_notes].presence
    end

    # What the notes field shows: what this request carried, or what the stored
    # decision said. Held apart from the record because an approval's note is not
    # saved until the run has happened — a draft that cannot be applied yet has not
    # been approved, and a re-render that dropped the sentence would make the reviewer
    # write it twice.
    def review_notes_field
      @review_notes || @review_request.review_notes
    end
end
