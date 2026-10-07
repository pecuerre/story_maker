# Writes one committed record's document to the index.
#
# The document is the argument rather than the record: by the time this runs the
# record may have been edited again or deleted, and the job must write the state
# that was committed, not whatever exists now.
#
# The engine answers a write with a task and applies it later, so the write is
# not finished when this method returns — and a refusal never raises: the engine
# refuses a batch over one document it dislikes, and nothing in the request that
# queued this ever hears about it. The task is therefore read before returning.
# A refusal is logged rather than raised, because a search service refusing a
# document is not a reason to retry a queue of index writes indefinitely, and the
# index is derived data: `bin/rails search:reindex` is the honest way to bring it
# back. What the log has to carry is the document, because a refusal with no
# document named is a gap nobody can find.
class Search::IndexRecordJob < ApplicationJob
  queue_as :default

  def perform(document)
    search_id = document.to_h["id"] || document[:id]
    refusal = Search::TaskWaiter.call(Search.backend.upsert(document))
    return if refusal.nil?

    Rails.logger.warn { "[search] could not index #{search_id}: #{refusal}" }
  rescue Meilisearch::Error => error
    # A synchronous refusal — raised before the task exists — arrives here. It is
    # the other half of the same gap: the engine accepted nothing, so there is no
    # task to read and no later moment at which anything would have been applied.
    Rails.logger.warn { "[search] could not index #{search_id}: #{error.message}" }
  end
end
