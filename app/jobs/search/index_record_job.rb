# Writes one committed record's document to the index.
#
# The document is the argument rather than the record: by the time this runs the
# record may have been edited again or deleted, and the job must write the state
# that was committed, not whatever exists now.
class Search::IndexRecordJob < ApplicationJob
  queue_as :default

  def perform(document)
    Search.backend.upsert(document)
  rescue Meilisearch::Error => error
    # A search service being down is not a reason to retry a queue of index
    # writes indefinitely. The index is derived data, and
    # `bin/rails search:reindex` is the honest way to bring it back.
    Rails.logger.warn { "[search] could not index #{document.to_h["id"] || document[:id]}: #{error.message}" }
  end
end
