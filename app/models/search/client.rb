module Search
  # The only place that speaks to Meilisearch.
  #
  # Everything the engine can refuse — an unreachable host, a missing key, a
  # filter on an index whose settings were never applied — is turned into
  # `Search::Unavailable` after being logged. The top bar renders on every page,
  # so a search failure must never become a failed request: the caller turns
  # this into a stated state, and the log keeps the reason.
  class Client
    PRIMARY_KEY = "id"
    # Only a record's own words are searchable. A universe or story *name* is
    # context, not content: matching every record of a universe because someone
    # typed its name would bury the record they meant.
    #
    # The top-level keys are snake_case because the Ruby client converts them to
    # the engine's camelCase — and warns when it is given camelCase itself. The
    # conversion is top-level only, so the one nested key is written the way the
    # engine wants it: sent as snake_case, Meilisearch refuses the whole settings
    # update with `Unknown field`.
    SETTINGS = {
      searchable_attributes: %w[ title body ],
      filterable_attributes: %w[ kind taxonomy universe_id story_id ],
      displayed_attributes: %w[ id kind taxonomy universe_id story_id title body url updated_at ],
      # Enough headroom for a large universe's match count to be stated honestly
      # on the results page.
      pagination: { maxTotalHits: 1000 }
    }.freeze

    def initialize(configuration, client: nil)
      @configuration = configuration
      @client = client
    end

    def available?
      true
    end

    # Returns a `Search::ResultSet`. Raises `Search::Unavailable` when the engine
    # cannot answer, so an unconfigured or broken engine is never mistaken for an
    # empty result.
    def search(text:, filter: nil, limit: 10, offset: 0)
      response = index.search(text.to_s, { limit: limit, offset: offset }.merge(filter ? { filter: filter } : {}))
      hits = Array(response["hits"]).map { |hit| Hit.from_engine(hit) }

      ResultSet.new(hits: hits, total: response["estimatedTotalHits"] || response["nbHits"] || hits.size,
        took_ms: response["processingTimeMs"])
    rescue Meilisearch::Error => error
      raise Unavailable, error.message
    end

    # Documents are written one record at a time by a background job, and in bulk
    # by the reindex task. Both return the engine's task so the caller can await
    # it when it needs the write to be visible before it continues.
    def upsert(documents)
      list = documents.is_a?(Hash) ? [ documents ] : Array(documents)
      return if list.blank?

      index.add_documents(list.map { |document| stringify(document) }, PRIMARY_KEY)
    end

    # Meilisearch creates an index implicitly on the first write, but only with a
    # primary key it guessed. Settings still have to be applied separately, and
    # only to an index that exists, so a reindex names it explicitly.
    def create_index
      client.create_index(configuration.index_name, { primary_key: PRIMARY_KEY })
    end

    def remove(search_id)
      return if search_id.blank?

      index.delete_document(search_id)
    end

    def remove_all
      index.delete_all_documents
    end

    def apply_settings
      index.update_settings(SETTINGS)
    end

    def settings
      index.settings
    rescue Meilisearch::Error => error
      raise Unavailable, error.message
    end

    def stats
      client.index(configuration.index_name).stats
    rescue Meilisearch::Error => error
      raise Unavailable, error.message
    end

    def index_exists?
      client.fetch_index(configuration.index_name)
      true
    rescue Meilisearch::Error
      false
    end

    def health
      client.health
    rescue Meilisearch::Error => error
      raise Unavailable, error.message
    end

    private
      attr_reader :configuration

      def client
        @client ||= Meilisearch::Client.new(configuration.url, configuration.api_key,
          timeout: configuration.search_timeout, max_retries: Configuration::MAX_RETRIES)
      end

      def index
        @index ||= begin
          search_client = Meilisearch::Client.new(configuration.url, configuration.api_key,
            timeout: configuration.write_timeout, max_retries: Configuration::MAX_RETRIES)
          search_client.index(configuration.index_name)
        end
      end

      # Meilisearch's primary key must be a string, and a nil field would be
      # rejected for the whole batch, so the document is normalised here rather
      # than in each model.
      def stringify(document)
        document.to_h.transform_keys(&:to_s)
      end
  end
end
