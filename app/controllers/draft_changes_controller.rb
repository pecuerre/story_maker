# Dropping one remembered change from a draft that has not been applied yet.
#
# **This is the per-change control ADR 0021 deferred.** A draft that holds one
# change the applier cannot read is refused in words rather than run, and before
# this the author's only way out of that state was **Discard**, which throws away
# every other change in the draft with it. A change that cannot be interpreted has
# no conflict page to answer on — there is nothing to choose between — so the control
# belongs beside the change itself, on the draft's own page.
#
# **The change is destroyed, not rewritten.** A remembered change is append-only in
# the sense that what it says is never edited: a rewritten payload would still carry
# a `base_version` captured against the original values. Dropping is the author
# withdrawing their intent before anything was written, which is why it deletes the
# row rather than storing a new state for it. No outcome row is written either: a
# dropped change was never part of an apply run, and a draft's history records runs.
# See ADR 0036 for the decision.
#
# **Only a working draft can lose a change.** A submitted draft is with a reviewer,
# and the promise of that mode is that what was reviewed is what was submitted, so
# its author withdraws it by discarding the whole draft rather than by editing it
# underneath the reviewer. An applied or discarded draft is history. Both refusals
# answer on the draft's own page, where the control that still applies lives.
#
# **A change is reached only through its own draft.** The draft is read as its own
# author's inside the universe the request has already authorized, and the change is
# then looked up on that draft's association. Another author's draft, another
# universe's draft, and a change belonging to a different draft are one 404 — the
# same answer `DraftsController` gives, because pending work is not a permission
# decision and must not be an oracle for what somebody else is working on.
class DraftChangesController < ApplicationController
  before_action :set_draft
  before_action :set_change

  # DELETE /u/:universe_slug/drafts/:draft_id/changes/:id
  #
  # Drops the change and answers the draft's own page. The flash counts what is still
  # waiting, because the most important part of this outcome is what it did *not*
  # remove: the rest of the draft is untouched and still applies.
  def destroy
    return refuse_closed_draft unless @draft.open?
    return refuse_submitted_draft unless @draft.draft?

    @change.destroy!

    redirect_to universe_draft_path(universe_slug: Current.universe.slug, id: @draft),
      notice: t("drafts.flash.change_dropped", count: remaining_change_count), status: :see_other
  end

  private
    # The reader's own drafts in this universe, the same scope `DraftsController`
    # looks through. It is stated here rather than shared through a concern because
    # this controller reaches a draft in one place; a second caller is when that
    # extraction earns its keep.
    def set_draft
      @draft = Current.universe.drafts.where(user: Current.user).find(params.expect(:draft_id))
    end

    # **Scoped through the draft, not through the universe.** A change id is not a
    # draft id, and a valid change belonging to somebody else's draft must not be
    # droppable by guessing it.
    def set_change
      @change = @draft.draft_changes.find(params.expect(:id))
    end

    # What is still waiting after the drop. The association is reloaded rather than
    # counted from the proxy that resolved the change, so the number is the database's
    # answer to "what remains" and not a collection that may still hold the row just
    # destroyed.
    def remaining_change_count
      @draft.draft_changes.reload.count
    end

    def refuse_closed_draft
      redirect_to universe_draft_path(universe_slug: Current.universe.slug, id: @draft),
        alert: t("drafts.flash.closed"), status: :see_other
    end

    # A submitted draft is open, so it reaches the status check above rather than the
    # closed one, and it needs its own sentence: "already applied or discarded" would
    # be a wrong reason for a draft that is very much still waiting.
    def refuse_submitted_draft
      redirect_to universe_draft_path(universe_slug: Current.universe.slug, id: @draft),
        alert: t("drafts.flash.change_locked_for_review"), status: :see_other
    end
end
