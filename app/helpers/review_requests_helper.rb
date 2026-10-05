module ReviewRequestsHelper
  # How many submissions in this universe are still waiting for a reviewer, which is
  # what the sidebar's **Review requests** entry carries.
  #
  # **It counts what is waiting, not what the queue holds.** The queue lists decided
  # and withdrawn submissions behind the pending ones because they are the record of
  # who let a change through, and a sidebar figure counting those would be a number
  # about history rather than about work: a reviewer opening the entry to find out
  # whether anything needs them would be told twelve when nothing does.
  #
  # **It is deliberately uncached**, which is the one thing about it that is unlike
  # the left sidebar's counts. Those are `MenuCountCache` entries because they answer
  # about records, whose counts move for reasons that are not this request's news.
  # This one moves *because of a decision the reviewer has just made*: an approval or
  # a rejection has to be able to lower the figure on the page it redirects to, or
  # the sidebar would contradict the decision that was just taken for up to an hour.
  # So it is one `COUNT` over one indexed column (`review_requests.universe_id`),
  # asked only by the readers who may see the queue at all.
  #
  # **It asks the `pending` scope, and `ReviewRequestsController#index` sorts on
  # `waiting?`.** Those are the same question today — `waiting?` is `pending?` — and
  # the pill and the page it opens are therefore the same rows; a status that
  # separates them would have to answer both, and both are a line apart.
  #
  # Memoized for the length of the render, because nothing here is ever carried to a
  # later request.
  def pending_review_request_count
    return @pending_review_request_count if defined?(@pending_review_request_count)
    return @pending_review_request_count = 0 if Current.universe.nil?

    @pending_review_request_count = Current.universe.review_requests.pending.count
  end
end
