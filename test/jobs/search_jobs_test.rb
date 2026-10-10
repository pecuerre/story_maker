require "test_helper"

# A search write is queued, so the job is where a refusal the engine accepted and
# then applied actually surfaces. `test/models/search/reindexer_test.rb` covers the
# command path awaiting its tasks; these cases cover the two paths that had no
# equivalent, where a refusal arrives *after* the call that queued the write has
# already returned and nothing raises at all.
class SearchJobsTest < ActiveSupport::TestCase
  # A task the way the engine answers one: the write is acknowledged, and the
  # refusal is a fact about the task rather than an exception.
  Task = Struct.new(:type, :failure) do
    def await = self

    def failed? = failure.present?
    def error = failure
  end

  # An engine that accepts the request and then refuses it. Both halves the quirk
  # named: a synchronous error raised before the task exists, and a task the
  # engine later marks `failed`, which never raises.
  class RefusingBackend
    attr_reader :written, :removed

    def initialize(refuse_task: false)
      @written = []
      @removed = []
      @refuse_task = refuse_task
    end

    def available? = true
    def reason = nil

    def upsert(documents)
      list = documents.is_a?(Hash) ? [ documents ] : Array(documents)
      @written.concat(list)
      return refusing_task(:documentAdditionOrUpdate, ids_in(list)) if @refuse_task

      raise Meilisearch::Error, "the engine refused to index #{ids_in(list)}"
    end

    def remove(search_id)
      @removed << search_id
      return refusing_task(:documentDeletion, search_id) if @refuse_task

      raise Meilisearch::Error, "the engine refused to remove #{search_id}"
    end

    private
      def refusing_task(type, subject)
        Task.new(type, { "code" => "invalid_document_id", "message" => "invalid_document_id: #{subject}" })
      end

      def ids_in(list)
        list.map { |document| document["id"] }.join(", ")
      end
  end

  setup do
    @backend = Search.backend = RefusingBackend.new
  end

  # The point of these: the job must not raise. An engine that is briefly
  # unavailable is not a reason to retry a queue of index writes indefinitely —
  # the index is derived data, and `bin/rails search:reindex` is the repair.
  test "an index write the engine refused synchronously is logged, not raised" do
    document = SearchTestBackend.document(id: "character-1", kind: "character", title: "Jonas",
      universe_id: 1)

    log = capture_log { Search::IndexRecordJob.perform_now(document) }

    assert_equal [ document ], @backend.written, "the write was attempted"
    assert_includes log, "could not index character-1"
    assert_includes log, "the engine refused to index character-1"
  end

  test "a removal the engine refused synchronously is logged, not raised" do
    log = capture_log { Search::RemoveRecordJob.perform_now("character-1") }

    assert_equal [ "character-1" ], @backend.removed, "the removal was attempted"
    assert_includes log, "could not remove character-1"
    assert_includes log, "the engine refused to remove character-1"
  end

  # The half that was invisible: nothing raises here, so a job that returned the
  # task unread logged nothing at all and the document was simply missing.
  test "a write the engine refuses when it applies the task is logged, not raised" do
    @backend = Search.backend = RefusingBackend.new(refuse_task: true)
    document = SearchTestBackend.document(id: "character-1", kind: "character", title: "Jonas",
      universe_id: 1)

    log = capture_log { Search::IndexRecordJob.perform_now(document) }

    assert_equal [ document ], @backend.written, "the write was attempted"
    assert_includes log, "could not index character-1"
    assert_includes log, "documentAdditionOrUpdate failed"
    assert_includes log, "invalid_document_id"
  end

  test "a removal the engine refuses when it applies the task is logged, not raised" do
    @backend = Search.backend = RefusingBackend.new(refuse_task: true)

    log = capture_log { Search::RemoveRecordJob.perform_now("character-1") }

    assert_equal [ "character-1" ], @backend.removed, "the removal was attempted"
    assert_includes log, "could not remove character-1"
    assert_includes log, "documentDeletion failed"
    assert_includes log, "invalid_document_id"
  end

  # An engine that accepts a write and applies it.
  class AcceptingBackend < RefusingBackend
    def upsert(documents)
      list = documents.is_a?(Hash) ? [ documents ] : Array(documents)
      @written.concat(list)
      Task.new(:documentAdditionOrUpdate, nil)
    end

    def remove(search_id)
      @removed << search_id
      Task.new(:documentDeletion, nil)
    end
  end

  # The success half, which is the half that has to stay quiet: a task the engine
  # applied is not a warning, and a line per save would make the log unreadable
  # and bury the refusals above.
  test "a write the engine applied logs nothing" do
    @backend = Search.backend = AcceptingBackend.new
    document = SearchTestBackend.document(id: "character-1", kind: "character", title: "Jonas",
      universe_id: 1)

    log = capture_log { Search::IndexRecordJob.perform_now(document) }

    assert_equal [ document ], @backend.written, "the write was still made"
    assert_empty log
  end

  test "a removal the engine applied logs nothing" do
    @backend = Search.backend = AcceptingBackend.new

    log = capture_log { Search::RemoveRecordJob.perform_now("character-1") }

    assert_equal [ "character-1" ], @backend.removed, "the removal was still made"
    assert_empty log
  end

  # A backend that is not configured has no task to wait for. Reading it must be
  # a no-op rather than a NoMethodError on nil.
  test "an unconfigured engine is neither a warning nor an error" do
    Search.backend = Search::UnavailableBackend.new

    log = capture_log do
      Search::IndexRecordJob.perform_now(
        SearchTestBackend.document(id: "character-1", kind: "character", title: "Jonas", universe_id: 1)
      )
      Search::RemoveRecordJob.perform_now("character-1")
    end

    assert_not_includes log, "could not"
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

  # The same two cases for the two levels below a universe. A story destroyed
  # after its rename queued this work leaves nothing to rewrite, exactly as a
  # destroyed universe does, and must answer the same way.
  test "a reindex for a story that no longer exists does nothing" do
    log = capture_log { Search::ReindexStoryJob.perform_now(ActiveRecord::FixtureSet.identify(:gone)) }

    assert_empty log
  end

  test "a reindex for a live story reports what it wrote" do
    story = stories(:story_one)
    Search.backend = SearchTestBackend.new

    log = capture_log { Search::ReindexStoryJob.perform_now(story.id) }

    assert_includes log, story.name
    assert_match(/indexed \d+ document/, log)
    refute_includes log, "search is not available"
  end

  test "a reindex for a scene that no longer exists does nothing" do
    log = capture_log { Search::ReindexSceneJob.perform_now(ActiveRecord::FixtureSet.identify(:gone)) }

    assert_empty log
  end

  test "a reindex for a live scene reports what it wrote" do
    scene = scenes(:scene_one)
    Search.backend = SearchTestBackend.new

    log = capture_log { Search::ReindexSceneJob.perform_now(scene.id) }

    assert_includes log, scene.name
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
