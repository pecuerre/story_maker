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
# mutation controls, because acting on a draft *is* the page. The two controls are
# shown only while the draft can still be acted on, which is `Draft#open?` read
# once here rather than re-derived in the view.
#
# `apply` is the one action that can answer with a page of its own: when it finds
# conflicts it renders them instead of writing, because the author's answer is
# what the write is waiting for. That page is `drafts/conflicts`, it is a `422`
# (this is an apply being refused until it is told what to do), and it posts back
# to the same action — so `apply` is reached twice on that journey, once to show
# the question and once with the answers.
class DraftsController < ApplicationController
  before_action :set_draft, only: %i[ show apply discard ]

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
  end

  # POST /u/:universe_slug/drafts/:id/apply
  #
  # Writes the changes through the live mutation path and closes the draft. See
  # `DraftApplier` for why the draft is closed even when a change is skipped.
  #
  # **A conflict stops the apply and is shown instead.** The detector is asked on
  # *this* request rather than remembered from the last one, so the conflicts the
  # author is asked about are the ones this apply would otherwise skip: a record
  # that moved while the page was open is a conflict they have not answered, and
  # the page comes back with it. Nothing is written until every conflict has an
  # answer, and the answers are not remembered either — they belong to this
  # request, which is why a failed apply leaves a draft that simply asks again.
  def apply
    return refuse_closed_draft unless @draft.open?

    conflicts = DraftConflictDetector.new(@draft).conflicts
    answers = submitted_answers

    return show_conflicts(conflicts, answers) unless answered_all?(conflicts, answers)

    result = DraftApplier.new(@draft, answers: answers).apply

    redirect_to universe_draft_path(universe_slug: Current.universe.slug, id: @draft),
      notice: apply_notice(result), status: :see_other
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
  def discard
    return refuse_closed_draft unless @draft.open?

    @draft.update!(status: "discarded", closed_at: Time.current)

    redirect_to universe_drafts_path(universe_slug: Current.universe.slug),
      notice: t("drafts.flash.discarded"), status: :see_other
  end

  private
    def drafts
      Current.universe.drafts.where(user: Current.user)
    end

    # The conflicts, as the page that asks about them needs them.
    #
    # The answers are kept only if they are answers for a conflict on *this*
    # page: a hidden field carrying yesterday's choice for a change that no
    # longer conflicts would be an answer to a question nobody asked, and the
    # applier would happily treat it as an instruction to write over a record
    # that is perfectly fine. Filtering here is what makes the page's question
    # and the applier's answers one list.
    def show_conflicts(conflicts, answers)
      @conflicts = conflicts
      @answers = answers.slice(*conflicts.map { |conflict| conflict.change.id.to_s })

      render :conflicts, status: :unprocessable_content
    end

    # The answers this request carries, keyed by change id and valued with one
    # of `DraftApplier::ANSWERS`.
    #
    # A missing `resolutions` param is an empty list rather than an error, and
    # anything that is not a plain hash is dropped whole: an answer is an
    # instruction to write over somebody else's record, so it is read from a
    # shape this application produced rather than from whatever arrived.
    def submitted_answers
      raw = params[:resolutions]
      return {} unless raw.respond_to?(:to_unsafe_h)

      raw.to_unsafe_h.each_with_object({}) do |(change_id, answer), answers|
        answers[change_id.to_s] = answer.to_s if DraftApplier::ANSWERS.include?(answer.to_s)
      end
    end

    def answered_all?(conflicts, answers)
      conflicts.all? { |conflict| answers.key?(conflict.change.id.to_s) }
    end

    def set_draft
      @draft = drafts.find(params.expect(:id))
    end

    # An applied or discarded draft is history. Applying it again would write a
    # remembered create a second time, so the answer is the draft's own page with
    # the reason rather than a silent no-op.
    def refuse_closed_draft
      redirect_to universe_draft_path(universe_slug: Current.universe.slug, id: @draft),
        alert: t("drafts.flash.closed"), status: :see_other
    end

    # What an apply did, as one or two sentences: what was written, then what the
    # author chose to leave alone. They stay separate because they are separate
    # outcomes — a change dropped on purpose was not skipped, is not in `skipped`,
    # and does not make the apply partial — so folding it into either count would
    # report the apply as failed when the author simply decided.
    def apply_notice(result)
      sentences = []
      sentences << progress_sentence(result) unless only_keeping?(result)
      sentences << t("drafts.flash.kept_theirs", count: result.kept_count) if result.kept_count.positive?

      sentences.join(" ")
    end

    # An apply where nothing was written because every conflict was answered
    # `"theirs"` has no progress to report. "0 remembered changes are now live"
    # answers a question the author did not ask and buries the one they did, so
    # the kept sentence stands alone — unless something was also refused, which
    # is news the partial sentence has to carry either way.
    def only_keeping?(result)
      result.complete? && result.applied_count.zero? && result.kept_count.positive?
    end

    # What an apply did, in one sentence. A draft applied whole and a draft where
    # some changes could not be written are different sentences because they are
    # different outcomes, and the second one says that the changes are still
    # listed rather than implying they are gone.
    def progress_sentence(result)
      return t("drafts.flash.applied", count: result.applied_count) if result.complete?

      t("drafts.flash.partially_applied", applied: result.applied_count, skipped: result.skipped_count)
    end
end
