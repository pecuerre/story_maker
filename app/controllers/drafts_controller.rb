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
#
# **A draft the applier cannot read is refused before it is run, in words rather than as
# a 404.** `DraftIntegrity` is asked first, because an unreadable remembered change is not
# a conflict — there is nothing to choose between — and letting the applier raise would
# answer "this draft does not exist" for a draft that is sitting right there. See
# `DraftIntegrity` and ADR 0021, whose decision to *refuse* such a change is unchanged:
# only the shape of the answer is.
class DraftsController < ApplicationController
  include AppliesDrafts

  before_action :set_draft, only: %i[ show apply discard ]
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
    return show_damaged if @damaged.damaged?

    conflicts = draft_conflicts(@draft)
    answers = submitted_answers

    return show_conflicts(conflicts, answers) unless answered_all?(conflicts, answers)

    result = DraftApplier.new(@draft, answers: answers).apply

    redirect_to universe_draft_path(universe_slug: Current.universe.slug, id: @draft),
      notice: draft_apply_notice(result), status: :see_other
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
    def refuse_closed_draft
      redirect_to universe_draft_path(universe_slug: Current.universe.slug, id: @draft),
        alert: t("drafts.flash.closed"), status: :see_other
    end
end
