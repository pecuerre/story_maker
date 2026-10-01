# Removes sessions that can no longer be used.
#
# A session ends on its own as soon as a request finds it expired — the cookie
# is refused and the browser stops presenting it — so nothing *depends* on this
# job running. What it prevents is the table growing without bound: a session
# row for a browser nobody returns to is dead weight that is never read again.
#
# It is safe to run while the application is serving requests. It deletes only
# rows whose absolute deadline has passed, and a session that is past its
# deadline is refused by `Session#active?` whether or not its row still exists.
class PurgeExpiredSessionsJob < ApplicationJob
  queue_as :default

  # A single delete statement, so a large backlog of expired rows is one
  # statement rather than a batch loop that holds a transaction open. The rows
  # are already unusable, so there is nothing to preserve and nothing to
  # cascade.
  def perform
    removed = Session.expired.delete_all

    Rails.logger.info { "[sessions] removed #{removed} expired session(s)" }
    removed
  end
end
