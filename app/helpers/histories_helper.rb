module HistoriesHelper
  # How many drafts have closed in this universe, which is what the sidebar's
  # **Change history** entry carries.
  #
  # **It counts runs, not changes, and it counts discarded drafts as well as
  # applied ones.** The page groups by draft and a draft is the unit it draws, so a
  # figure counting remembered changes would not be the number of rows above it. A
  # discarded draft is included because the page lists it: an entry whose pill is
  # lower than the page it opens is a figure answering a different question, and
  # "how much did somebody throw away" is part of the same history.
  #
  # **It is deliberately uncached**, for `ReviewRequestsHelper`'s reason: it moves
  # because a run happened on this request, so a `MenuCountCache` entry could hold a
  # stale figure for up to its TTL. It is one `COUNT` over one indexed column
  # (`drafts.universe_id`) asked only by the readers who may see the page at all.
  #
  # Memoized for the length of the render, because nothing here is ever carried to a
  # later request.
  def closed_draft_count
    return @closed_draft_count if defined?(@closed_draft_count)
    return @closed_draft_count = 0 if Current.universe.nil?

    @closed_draft_count = Current.universe.drafts.closed.count
  end
end
