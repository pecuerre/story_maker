require "test_helper"

# A search write is queued, so the job is where a refusal the engine accepted and
# then applied actually surfaces. `test/models/search/reindexer_test.rb` covers the
# command path awaiting its tasks; these cases cover the paths that do not await
# anything, which is why the same refusal is invisible from the request that queued
# the write. Known quirk 56.
class SearchJobsTest < ActiveSupport::TestCase
  # An engine that accepted the request and refused it when it applied it. Nothing
  # in the calling request ever sees this.
  class RefusingBackend
    attr_reader :written, :removed

    def initialize
      @written = []
      @removed = []
    end

    def available? = true
    def reason = nil

    def upsert(documents)
      list = documents.is_a?(Hash) ? [ documents ] : Array(documents)
      @written.concat(list)
      raise Meilisearch::Error, "the engine refused to index #{ids_in(list)}"
    end

    def remove(search_id)
      @removed << search_id
      raise Meilisearch::Error, "the engine refused to remove #{search_id}"
    end

    private
      def ids_in(list)
        list.map { |document| document["id"] }.join(", ")
      end
  end

  setup do
    @backend = RefusingBackend.new
    Search.backend = @backend
  end

  # The point of these two: the job must not raise. An engine that is briefly
  # unavailable is not a reason to retry a queue of index writes indefinitely —
  # the index is derived data, and `bin/rails search:reindex` is the repair.
  test "an index write the engine refused is logged, not raised" do
    document = SearchTestBackend.document(id: "character:1", kind: "character", title: "Jonas",
      universe_id: 1)

    log = capture_log { Search::IndexRecordJob.perform_now(document) }

    assert_equal [ document ], @backend.written, "the write was attempted"
    assert_includes log, "could not index character:1"
    assert_includes log, "the engine refused to index character:1"
  end

  test "a removal the engine refused is logged, not raised" do
    log = capture_log { Search::RemoveRecordJob.perform_now("character:1") }

    assert_equal [ "character:1" ], @backend.removed, "the removal was attempted"
    assert_includes log, "could not remove character:1"
    assert_includes log, "the engine refused to remove character:1"
  end

  # A universe destroyed after its rename queued this work has no subject left.
  # The job must say so by doing nothing rather than raising for a record the
  # rename itself removed.
  test "a reindex for a universe that no longer exists does nothing" do
    log = capture_log { Search::ReindexUniverseJob.perform_now(ActiveRecord::FixtureSet.identify(:gone)) }

    assert_empty log
  end

  # The success half: a rename is repaired by a job that nobody is watching, so the
  # only record that it ran is the log line.
  test "a reindex for a live universe reports what it wrote" do
    universe = universes(:universe_one)
    Search.backend = SearchTestBackend.new

    log = capture_log { Search::ReindexUniverseJob.perform_now(universe.id) }

    assert_includes log, universe.name
    assert_match(/indexed \d+ document/, log)
    refute_includes log, "search is not available"
  end

  private
    def capture_log
      output = StringIO.new
      previous = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(output)
      yield
      output.string
    ensure
      Rails.logger = previous
    end
end
