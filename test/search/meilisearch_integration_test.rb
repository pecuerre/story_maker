require "test_helper"

# The search engine itself, against a real Meilisearch.
#
# Everything else in the suite uses `SearchTestBackend`, which is a stand-in for
# the application's side of the conversation. That is deliberate — CI has no
# search service, and a suite that needed one would be a suite that could not be
# run by a contributor without Docker. But it means the engine's own contract is
# untested by default, and that contract has real teeth: a document id it refuses,
# a setting it will not apply, and a filter on an index whose settings were never
# applied all fail *quietly*. Every one of those was found by running this file
# against a real instance during development.
#
# So it is opt-in and deliberate, not part of the suite:
#
#   docker run --rm -p 7700:7700 \
#     -e MEILI_MASTER_KEY=local_development_key -e MEILI_ENV=development \
#     getmeili/meilisearch:v1.54
#   MEILISEARCH_URL=http://127.0.0.1:7700 \
#   MEILISEARCH_API_KEY=local_development_key \
#   SEARCH_INTEGRATION=1 bin/rails test test/search
#
# `MEILISEARCH_INDEX_PREFIX` isolates this from any other index on the same
# engine, and the prefix is suffixed with the test environment, so this can never
# touch a development or deployed index.
class MeilisearchIntegrationTest < ActiveSupport::TestCase
  INTEGRATION = ENV["SEARCH_INTEGRATION"] == "1"

  def setup
    skip "set SEARCH_INTEGRATION=1 and MEILISEARCH_URL to run against a real engine" unless INTEGRATION

    @backend = Search::Client.new(
      Search::Configuration.new(
        url: ENV.fetch("MEILISEARCH_URL"),
        api_key: ENV["MEILISEARCH_API_KEY"],
        index_prefix: ENV["MEILISEARCH_INDEX_PREFIX"].presence || "universe_maker_test_run",
        environment: "integration"
      )
    )
    @universe = universes(:universe_one)
    @character = characters(:character_one)
  end

  def teardown
    return unless INTEGRATION

    begin
      @backend.remove_all.await
    rescue Meilisearch::Error
      nil
    end
  end

  test "the engine accepts every document the registry can build" do
    # This is the assertion that matters most: one document the engine refuses
    # fails its whole batch, and a reindex that does not check its tasks reports
    # success while storing nothing.
    documents = Search::Registry::MODELS.filter_map { |model| model.first&.search_document }
    task = @backend.upsert(documents)

    task.await
    assert task.succeeded?, "the engine refused a document: #{task.error}"
    assert_equal documents.size, @backend.stats.fetch("numberOfDocuments")
  end

  test "the settings the filter depends on are applied, and a filter then works" do
    @backend.create_index.await
    settings = @backend.apply_settings
    settings.await
    assert settings.succeeded?, "the engine refused the index settings: #{settings.error}"

    document = @character.search_document
    @backend.upsert(document).await

    result = @backend.search(text: "Character one", filter: "universe_id = #{@universe.id}")
    assert_equal [ @character.search_id ], result.hits.map(&:id)

    # A scope that is not the reader's must filter the answer out rather than be
    # fetched and hidden afterwards.
    empty = @backend.search(text: "Character one", filter: "universe_id = #{@universe.id + 999}")
    assert_empty empty.hits
  end

  test "a document id the engine refuses fails its whole batch" do
    # Recorded as a test rather than a comment because it is the failure mode that
    # cost a reindex: 214 documents reported as written, none stored, and nothing
    # raised.
    task = @backend.upsert([ { "id" => "not:valid", "kind" => "character" } ])

    task.await
    assert task.failed?
  end

  test "a search finds a record by its own words and not by its context's names" do
    @character.update!(description: "A traveller with a grey hat")
    @universe.update!(name: "Zebulon")
    @backend.upsert(@character.search_document).await

    assert_equal [ @character.search_id ],
      @backend.search(text: "grey hat").hits.map(&:id)
    assert_empty @backend.search(text: "Zebulon").hits,
      "a universe name is context, not something to match"
  end

  test "removing a document takes it out of the index" do
    @backend.upsert(@character.search_document).await
    assert_equal 1, @backend.search(text: "Character one").hits.size

    @backend.remove(@character.search_id).await

    assert_empty @backend.search(text: "Character one").hits
  end

  test "a full reindex reports what it wrote and the engine agrees" do
    summary = Search::Reindexer.new(backend: @backend).call

    assert_nil summary.unavailable
    assert summary.documents.positive?
    assert_equal summary.documents, @backend.stats.fetch("numberOfDocuments")
  end

  test "an engine that is not there is unavailable, not a crash" do
    unreachable = Search::Client.new(
      Search::Configuration.new(url: "http://127.0.0.1:1", search_timeout: 0.2)
    )

    assert_raises(Search::Unavailable) { unreachable.search(text: "anything") }
  end
end
