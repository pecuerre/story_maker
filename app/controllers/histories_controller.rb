# What happened to this universe's content: every closed draft, newest first, grouped
# by the day it closed.
#
# **The action asks for `admin` on the universe**, through `UniverseAuthorization`,
# which is the same line memberships and the review queue use. That is not a stronger
# version of the drafts pages' `read`/`write` split, it is a different question: those
# answer "may this person see and act on their own pending work", this one answers
# "may this person see what other people have done here". The list is itself the
# answer, because it names every author who has ever closed a draft in this universe,
# and a plain writer has no business reading that.
#
# **A discarded draft is on this page, and its changes are marked as never having
# been written.** The alternative — showing only applied drafts — would answer "who
# changed this universe" with a list that silently omits the work somebody threw
# away, which is the half of the history an admin is more likely to need. Nothing in
# the model marks those changes as never having existed, so the page says so itself:
# `DraftChanges::Reader` resolves no record for a create that was never applied, and
# each change carries the outcome the run stored, or none where no run happened.
#
# **Grouped by `closed_at`, the day the run happened, rather than by a change's own
# `created_at`,** which is when it was first remembered and can be days earlier. A
# reader asking "what did this universe look like on Tuesday" is asking about runs,
# not about intentions.
#
# **The rows are the same rows a draft's own page draws.** Each change is rendered
# through `drafts/_change` with the whole page's changes as its `changes` local, so
# every row on the page shares one `DraftChanges::Reader` and resolves its records
# and tag names in one query per class rather than one per row — finding 66, which a
# universe-wide list is exactly where that cost shows up.
class HistoriesController < ApplicationController
  # GET /u/:universe_slug/history
  #
  # Every closed draft in this universe, newest first, grouped by day. The sort is
  # `closed_at` rather than `id` because the day heading is the grouping, and the
  # id is only the tiebreaker for two drafts that closed inside one clock tick.
  #
  # **Newest day first.** This page answers "what happened lately", and the answer to
  # that is at the top; history sorted oldest-first would make every visit start at
  # the beginning of the universe.
  #
  # The changes are preloaded onto the array the view iterates rather than onto a
  # discarded relation, for `DraftsController#set_changes`' reason: `includes` returns
  # a new relation, so a preload that is not assigned attaches to instances nobody
  # renders and each row resolves its own outcome.
  #
  # **`:user` is preloaded for the same reason.** The page names the author of every
  # draft, and an association read in the view is one query per draft rather than one
  # per author — which is finding 66's shape again, in a list whose whole purpose is to
  # be long. `draft_changes_query_count_test.rb` is what caught it.
  def index
    @drafts = Current.universe.drafts.closed
      .includes(:user, draft_changes: :outcome)
      .order(closed_at: :desc, id: :desc).to_a
    @changes = @drafts.flat_map(&:draft_changes)
  end
end
