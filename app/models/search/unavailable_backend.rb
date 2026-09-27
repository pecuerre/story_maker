module Search
  # Stands in for the engine when one is not configured.
  #
  # A deployment without `MEILISEARCH_URL` is a normal state — a contributor
  # running the app before the engine is running, a test suite, an environment
  # where the service is deliberately not deployed. Reads say so; writes are
  # dropped with a log line rather than raising, so an unrelated save never fails
  # because search is not there. `bin/rails search:reindex` reports the same state
  # instead of pretending to have indexed anything.
  class UnavailableBackend
    REASON = "Search is not available. Set MEILISEARCH_URL and run bin/rails search:reindex."

    def available?
      false
    end

    def reason
      REASON
    end

    def search(*, **)
      raise Unavailable, REASON
    end

    def upsert(documents)
      list = documents.is_a?(Hash) ? [ documents ] : Array(documents)
      return if list.blank?

      Rails.logger.info { "[search] not indexing #{list.size} document(s): #{REASON}" }
      nil
    end

    def remove(search_id)
      return if search_id.blank?

      Rails.logger.info { "[search] not removing document #{search_id}: #{REASON}" }
      nil
    end

    def remove_all
      Rails.logger.info { "[search] not clearing the index: #{REASON}" }
      nil
    end

    def create_index
      Rails.logger.info { "[search] not creating the index: #{REASON}" }
      nil
    end

    def apply_settings
      Rails.logger.info { "[search] not applying index settings: #{REASON}" }
      nil
    end

    def settings
      raise Unavailable, REASON
    end

    def stats
      raise Unavailable, REASON
    end

    def index_exists?
      false
    end

    def health
      raise Unavailable, REASON
    end
  end
end
