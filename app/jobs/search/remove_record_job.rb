# Removes one destroyed record's document from the index.
#
# The id travels as a string: the record is already gone, so there is nothing to
# reload. A document that outlives its record is the one way a stale index
# disagrees with the database, which is why a destroy is indexed as carefully as
# a save.
class Search::RemoveRecordJob < ApplicationJob
  queue_as :default

  def perform(search_id)
    Search.backend.remove(search_id)
  rescue Meilisearch::Error => error
    Rails.logger.warn { "[search] could not remove #{search_id}: #{error.message}" }
  end
end
