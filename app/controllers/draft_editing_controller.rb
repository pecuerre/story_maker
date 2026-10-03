# The **Start editing** / **Stop editing** control on the universe page: the two
# halves of a reader's claim to be editing this universe in this session.
#
# **Neither action is a gate on remembering a change.** In a draft-based universe
# every mutation is remembered whether this reader pressed anything or not
# (`DraftMutation`, ADR 0020), and it is the flag — not this controller — that is
# forbidden from becoming the switch that decides it, because a reader who forgot
# to start editing would then write straight through a universe whose whole point
# is that it does not (ADR 0022). What starting does is open the draft **before**
# the first change is made, and what the flag gives the universe page is a count
# of what is waiting.
#
# **Both actions need `write` access**, which the shared universe policy already
# decides from the action name, and that is the same rule that governs where the
# control is rendered: an author who cannot write here has nothing to edit, so
# there is nothing to start. It also answers the case where an author's write
# access was revoked while they were editing — the control disappears with the
# access, rather than offering a mode whose changes could not be remembered.
#
# **A `direct` universe has no editing session at all**, because nothing in it is
# ever remembered. A posted toggle there is a stale page rather than a mistake the
# reader can act on, so it is answered with the universe and an explanation
# instead of silently pretending a session started.
class DraftEditingController < ApplicationController
  before_action :require_draft_based_universe

  # POST /u/:universe_slug/editing
  #
  # Claims the session and opens (or resumes) the one open draft this author has
  # here. A POST, so the redirect is the default 302 the HTML flow uses.
  def create
    DraftEditingSession.start!(session: session, user: Current.user, universe: Current.universe)

    redirect_to universe_path(universe_slug: Current.universe.slug),
      notice: t("drafts.flash.editing_started")
  end

  # DELETE /u/:universe_slug/editing
  #
  # Releases the claim and leaves the draft open. The flash names how much is
  # still waiting on it, because a reader who pressed **Stop editing** and then
  # found their pending work gone would have no way to know that stopping was the
  # cause rather than something they did.
  def destroy
    DraftEditingSession.stop!(session: session, universe: Current.universe)

    redirect_to universe_path(universe_slug: Current.universe.slug),
      notice: t("drafts.flash.editing_stopped", count: Draft.pending_changes_count(Current.user, Current.universe)),
      status: :see_other
  end

  private
    # A universe is always resolved by the time this runs: both routes are inside
    # the `u/:universe_slug` scope, so `set_current_universe` has already raised for
    # a slug that names nothing, and the authorization callback has already answered
    # `read` before it asked for `write`.
    def require_draft_based_universe
      return if Current.universe.draft_based?

      redirect_to universe_path(universe_slug: Current.universe.slug),
        alert: t("drafts.flash.not_draft_based"), status: :see_other
    end
end
