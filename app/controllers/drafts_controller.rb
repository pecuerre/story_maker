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
  # Every change the draft remembers, in the order they were remembered. The page
  # reports what each change *says*; it does not claim a change was written, which
  # only the apply that wrote it can know.
  def show
  end

  # POST /u/:universe_slug/drafts/:id/apply
  #
  # Writes the changes through the live mutation path and closes the draft. See
  # `DraftApplier` for why the draft is closed even when a change is skipped.
  def apply
    return refuse_closed_draft unless @draft.open?

    result = DraftApplier.new(@draft).apply

    redirect_to universe_draft_path(universe_slug: Current.universe.slug, id: @draft),
      notice: apply_notice(result), status: :see_other
  end

  # POST /u/:universe_slug/drafts/:id/discard
  #
  # Rejecting a draft moves the **draft's** status rather than deleting anything:
  # a remembered change is append-only, so what the author decided about it is
  # recorded on the draft and the change itself keeps saying what it said.
  def discard
    return refuse_closed_draft unless @draft.open?

    @draft.update!(status: "discarded")

    redirect_to universe_drafts_path(universe_slug: Current.universe.slug),
      notice: t("drafts.flash.discarded"), status: :see_other
  end

  private
    def drafts
      Current.universe.drafts.where(user: Current.user)
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

    # What an apply did, in one sentence. A draft that was applied whole and a
    # draft where some changes could not be written are different sentences
    # because they are different outcomes, and the second one says that the
    # changes are still listed rather than implying they are gone.
    def apply_notice(result)
      if result.complete?
        t("drafts.flash.applied", count: result.applied_count)
      else
        t("drafts.flash.partially_applied", applied: result.applied_count, skipped: result.skipped_count)
      end
    end
end
