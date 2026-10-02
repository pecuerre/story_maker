# One conversation per record, reached from the record's own page.
#
# Which models include this is a deliberate list rather than "everything
# registered as content", and the exclusions are stated in the models that make
# them:
#
#   * `Photo` has no page of its own — it is displayed inside its record's page —
#     so a thread attached to one would have no place to be read.
#   * A record that is hard-deleted takes its thread with it, which only holds if
#     every path that removes the record also runs its callbacks.
#
# The universe is read through `UniverseScopeResolver` rather than by calling
# `universe` on the record, because a story-scoped record and a Scene-owned one
# reach their universe by different routes and there is already one walk that
# answers both.
module HasDiscussion
  extend ActiveSupport::Concern

  included do
    # A *soft* delete deliberately keeps the thread: the record can be restored,
    # and a restored record should find its conversation still there. Nothing
    # reads a thread through a soft-deleted record in the meantime — `RecordTarget`
    # refuses one — so the row is unreachable rather than disclosed.
    has_one :discussion, as: :record, dependent: :destroy
  end

  # The record's thread, created on first use.
  #
  # The two requests that can lose are a second read racing the first, and two
  # readers pressing **Discuss** at once. Both lose to the unique pair index
  # rather than to a second thread: the database refuses the second insert and the
  # row that won is read back. This is deliberately callable from a write action
  # only — the "Discuss" control posts here and follows the redirect — because a
  # `GET` that creates a thread is a page load that writes.
  def find_or_create_discussion
    discussion || create_discussion!(universe: UniverseScopeResolver.universe_for(self))
  rescue ActiveRecord::RecordNotUnique
    Discussion.find_by!(record: self)
  end
end
