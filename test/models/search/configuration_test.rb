require "test_helper"

# Where the engine is, and what an environment that says nothing is allowed to do.
class Search::ConfigurationTest < ActiveSupport::TestCase
  test "an unset URL means search is not available, and the application still boots" do
    configuration = Search::Configuration.new

    assert_not configuration.available?
    assert_not configuration.writable?
  end

  test "a URL alone is enough to read, because a local engine may run without a key" do
    configuration = Search::Configuration.new(url: "http://localhost:7700")

    assert configuration.available?
    assert_not configuration.writable?
  end

  test "writing needs a key, so a reindex can say which variable is missing" do
    configuration = Search::Configuration.new(url: "http://localhost:7700", api_key: "key")

    assert configuration.writable?
  end

  test "each environment gets its own index, so a development reindex cannot overwrite a deployment" do
    development = Search::Configuration.new(url: "http://localhost:7700", environment: "development")
    production = Search::Configuration.new(url: "http://localhost:7700", environment: "production")

    assert_equal "universe_maker_development", development.index_name
    assert_equal "universe_maker_production", production.index_name
    assert_not_equal development.index_name, production.index_name
  end

  test "the index prefix can be changed for a second deployment on one engine" do
    configuration = Search::Configuration.new(url: "http://localhost:7700",
      index_prefix: "staging", environment: "production")

    assert_equal "staging_production", configuration.index_name
  end

  test "the environment is read from the process" do
    configuration = Search::Configuration.from_env({})

    assert_equal Rails.env, configuration.environment
    assert_equal "universe_maker_#{Rails.env}", configuration.index_name
  end

  test "the environment variables are the documented ones, and blank ones are no configuration" do
    configuration = Search::Configuration.from_env(
      {
        "MEILISEARCH_URL" => "  http://localhost:7700  ",
        "MEILISEARCH_API_KEY" => "  ",
        "MEILISEARCH_INDEX_PREFIX" => ""
      }
    )

    assert_equal "http://localhost:7700", configuration.url
    assert_not configuration.writable?
    assert_equal "universe_maker_#{Rails.env}", configuration.index_name
    assert_equal %w[MEILISEARCH_URL MEILISEARCH_API_KEY MEILISEARCH_INDEX_PREFIX],
      [ Search::Configuration::URL_VARIABLE, Search::Configuration::KEY_VARIABLE,
        Search::Configuration::INDEX_PREFIX_VARIABLE ]
  end

  test "a search gets a short leash and indexing is allowed to be slower" do
    configuration = Search::Configuration.new(url: "http://localhost:7700")

    assert_operator configuration.search_timeout, :<, configuration.write_timeout
    assert_equal 1, Search::Configuration::MAX_RETRIES
  end

  test "an unconfigured process answers with the unavailable backend, not a crash" do
    Search.reset!

    assert_kind_of Search::UnavailableBackend, Search.backend
    assert_not Search.backend.available?
    assert_includes Search::UnavailableBackend::REASON, "MEILISEARCH_URL"
  end

  test "an unavailable backend refuses to answer a search and says why" do
    backend = Search::UnavailableBackend.new

    error = assert_raises(Search::Unavailable) { backend.search(text: "hannah") }

    assert_equal backend.reason, error.message
  end

  test "an unavailable backend drops writes instead of failing an unrelated save" do
    backend = Search::UnavailableBackend.new

    assert_nil backend.upsert({ id: "character-1" })
    assert_nil backend.remove("character-1")
    assert_nil backend.remove_all
    assert_nil backend.create_index
    assert_nil backend.apply_settings
    assert_not backend.index_exists?
  end

  test "an unavailable backend ignores a write of nothing rather than logging it" do
    backend = Search::UnavailableBackend.new

    assert_nil backend.upsert(nil)
    assert_nil backend.upsert([])
    assert_nil backend.remove(nil)
    assert_nil backend.remove("")
  end
end
