require "test_helper"

# A stand-in for the search engine, so the request and browser suites can prove
# what the application *does* with an answer — what the dropdown renders, what the
# results page states, what a reader is told when there is no engine — without a
# running Meilisearch in CI.
#
# It is deliberately dumb: it records the query it was asked and replays hits the
# test chose. It does not search, rank, filter, or enforce anything, because
# those are the engine's job and faking them would only prove the fake works. What
# *is* covered here is the code the engine cannot be asked about: which filter is
# built, what happens when the engine refuses, and how the answer is rendered.
# `test/search/meilisearch_integration_test.rb` covers the engine's own behaviour
# and is run deliberately, against a real instance.
class SearchTestBackend
  attr_reader :searches, :written, :removed
  attr_accessor :hits, :available

  def initialize(hits: [], available: true)
    @hits = hits
    @available = available
    @searches = []
    @written = []
    @removed = []
  end

  def available?
    @available
  end

  def reason
    Search::UnavailableBackend::REASON
  end

  # Hits are given as the engine would answer — string keys, no display fields —
  # so the normalization a real answer goes through is exercised too.
  def search(text:, filter: nil, limit: 10, offset: 0)
    @searches << { text: text, filter: filter, limit: limit, offset: offset }
    raise Search::Unavailable, reason unless available?

    hits = @hits.map { |hit| Search::Hit.from_engine(hit) }
    Search::ResultSet.new(hits: hits, total: hits.size)
  end

  def upsert(documents)
    list = documents.is_a?(Hash) ? [ documents ] : Array(documents)
    @written.concat(list)
    nil
  end

  def remove(search_id)
    @removed << search_id
    nil
  end

  def remove_all = nil
  def create_index = nil
  def apply_settings = nil

  def settings
    raise Search::Unavailable, reason
  end

  def stats
    raise Search::Unavailable, reason
  end

  def index_exists?
    available?
  end

  def health
    raise Search::Unavailable, reason
  end

  # A document as the engine would store it: string keys, ids instead of names.
  def self.document(id:, kind:, title:, universe_id:, story_id: nil, body: nil,
    taxonomy: nil, url: "/somewhere")
    {
      "id" => id,
      "kind" => kind,
      "taxonomy" => taxonomy,
      "universe_id" => universe_id,
      "story_id" => story_id,
      "title" => title,
      "body" => body,
      "url" => url,
      "updated_at" => 1_700_000_000
    }
  end
end

module SearchTestHelper
  # Replaces the engine for the duration of one test. `ActiveSupport::TestCase`
  # resets `Search` after every test, so no stub can leak into the next one.
  def stub_search_backend(hits: [], available: true)
    Search.backend = SearchTestBackend.new(hits: hits, available: available)
  end

  def search_backend
    Search.backend
  end
end

class ActiveSupport::TestCase
  teardown { Search.reset! }
end

class ActionDispatch::IntegrationTest
  include SearchTestHelper
end
