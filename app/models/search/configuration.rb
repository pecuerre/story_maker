module Search
  # Where the engine is, and how long the application is willing to wait for it.
  #
  # Everything is read from the environment so a deployment, a CI job, and a
  # developer's machine can differ without a code change, and so an unset
  # variable is a documented, ordinary state rather than a crash on boot.
  class Configuration
    URL_VARIABLE = "MEILISEARCH_URL"
    KEY_VARIABLE = "MEILISEARCH_API_KEY"
    INDEX_PREFIX_VARIABLE = "MEILISEARCH_INDEX_PREFIX"
    DEFAULT_INDEX_PREFIX = "universe_maker"
    # A search box sits on every page, so the engine gets a short leash: an
    # answer ("unavailable", or no results) beats a slow response. Indexing is
    # allowed to be slower because it happens in a background job.
    DEFAULT_SEARCH_TIMEOUT = 2.0
    DEFAULT_WRITE_TIMEOUT = 10.0
    # The client's own default is two retries, which would multiply the wait
    # above and still fail. One attempt keeps the worst case predictable.
    MAX_RETRIES = 1

    attr_reader :url, :api_key, :index_prefix, :environment,
      :search_timeout, :write_timeout

    def self.from_env(env = ENV, environment: Rails.env)
      new(
        url: env[URL_VARIABLE],
        api_key: env[KEY_VARIABLE],
        index_prefix: env[INDEX_PREFIX_VARIABLE],
        environment: environment
      )
    end

    def initialize(url: nil, api_key: nil, index_prefix: nil, environment: "development",
      search_timeout: DEFAULT_SEARCH_TIMEOUT, write_timeout: DEFAULT_WRITE_TIMEOUT)
      @url = url.to_s.strip.presence
      @api_key = api_key.to_s.strip.presence
      @index_prefix = index_prefix.to_s.strip.presence || DEFAULT_INDEX_PREFIX
      @environment = environment.to_s
      @search_timeout = search_timeout
      @write_timeout = write_timeout
    end

    # Reading is all the application needs in order to work, so the URL alone
    # makes search available. A local engine started without a key serves reads;
    # anything beyond development requires one.
    def available?
      url.present?
    end

    # Creating the index, changing its settings, and writing documents are all
    # refused without a key by any engine that is not in development mode, so
    # the reindex task can say which variable is missing instead of failing
    # halfway through.
    def writable?
      available? && api_key.present?
    end

    # One index per environment. A development or test reindex must never
    # overwrite the documents a deployed environment is serving, and a
    # development search must never read them.
    def index_name
      [ index_prefix, environment ].join("_")
    end
  end
end
