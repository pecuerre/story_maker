# Removes one destroyed record's document from the index.
#
# The id travels as a string: the record is already gone, so there is nothing to
# reload. A document that outlives its record is the one way a stale index
# disagrees with the database, which is why a destroy is indexed as carefully as
# a save.
#
# The engine answers a write with a task and applies it later, so a removal that
# is refused is refused *after* this method has already returned, and refuses
# nothing at all in the request that queued it. The task is read for the same
# reason the indexing job reads its own: a stale document with nothing to show
# for it is the one failure the engine reports least loudly. A refusal is logged
# rather than raised — the index is derived data and `bin/rails search:reindex`
# is the repair — but the id it failed on is in the line, which is what makes it
# findable.
class Search::RemoveRecordJob < ApplicationJob
  queue_as :default

  def perform(search_id)
    refusal = Search::TaskWaiter.call(Search.backend.remove(search_id))
    return if refusal.nil?

    Rails.logger.warn { "[search] could not remove #{search_id}: #{refusal}" }
  rescue Meilisearch::Error => error
    Rails.logger.warn { "[search] could not remove #{search_id}: #{error.message}" }
  end
end
