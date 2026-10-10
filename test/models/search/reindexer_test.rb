require "test_helper"

# Rebuilding the index. This is the bootstrap and the recovery path, so the parts
# that fail silently are the parts under test: the order of the writes, and a
# task the engine *refused* being reported rather than counted as a success.
class Search::ReindexerTest < ActiveSupport::TestCase
  # A recording stand-in that behaves like the engine's asynchronous writes: each
  # call hands back a task, and the task is where a refusal appears.
  class RecordingBackend
    Task = Struct.new(:type, :failed?, :error) do
      def await = self
    end

    attr_reader :calls
    attr_accessor :index_exists

    def initialize(failing: [])
      @calls = []
      @failing = failing
    end

    def available? = true
    def reason = nil

    def create_index
      record(:create_index)
    end

    def apply_settings
      record(:apply_settings)
    end

    def remove_all
      record(:remove_all)
    end

    def upsert(documents)
      list = documents.is_a?(Hash) ? [ documents ] : Array(documents)
      record(:upsert, list)
    end

    def remove_all=(_value); end

    private
      attr_reader :failing

      def record(type, payload = nil)
        @calls << [ type, payload ]
        return nil unless failing.include?(type)

        Task.new(type, true, { "message" => "invalid_document_id" })
      end
  end

  setup do
    @backend = RecordingBackend.new
  end

  test "the index is created, its settings applied, and its contents cleared before documents" do
    summary = Search::Reindexer.new(backend: @backend).call

    assert_equal %i[create_index apply_settings remove_all], @backend.calls.first(3).map(&:first)
    assert_operator summary.documents, :>, 0
    assert_nil summary.unavailable
  end

  test "every declared model contributes documents" do
    # The link records have no fixtures, and a model with no records legitimately
    # contributes no document — so they are created here, or this test would pass
    # with a model the reindex cannot actually reach.
    universe = universes(:universe_one)
    character = characters(:character_one)
    Relation.create!(universe: universe, character1: character, character2: characters(:character_two))
    Ownership.create!(universe: universe, character: character, item: items(:item_one))

    Search::Reindexer.new(backend: @backend).call

    indexed = @backend.calls.select { |type, _| type == :upsert }.flat_map { |_, list| list }
    kinds = indexed.map { |document| document[:kind] }.uniq

    Search::Registry::MODELS.each do |model|
      assert_includes kinds, model.search_declaration.kind, "#{model.name} contributed no document"
    end
  end

  test "documents are written in batches, not one request per record" do
    Search::Reindexer.new(backend: @backend).call

    upserts = @backend.calls.select { |type, _| type == :upsert }
    assert_operator upserts.size, :>, 1
    upserts.each { |_, list| assert_operator list.size, :<=, Search::Reindexer::BATCH_SIZE }
  end

  test "a write the engine refused is reported, not counted" do
    failing = RecordingBackend.new(failing: [ :upsert ])

    error = assert_raises(Search::ReindexFailed) { Search::Reindexer.new(backend: failing).call }

    assert_match "invalid_document_id", error.message
  end

  test "settings the engine refused is reported too" do
    failing = RecordingBackend.new(failing: [ :apply_settings ])

    assert_raises(Search::ReindexFailed) { Search::Reindexer.new(backend: failing).call }
  end

  test "an engine that is not there is reported as unavailable, not raised" do
    summary = Search::Reindexer.new(backend: Search::UnavailableBackend.new).call

    assert_equal Search::UnavailableBackend::REASON, summary.unavailable
    assert_equal 0, summary.documents
    assert_includes summary.to_s, "not available"
  end

  test "a universe reindex writes that universe and not the Universe document itself" do
    universe = universes(:universe_one)

    summary = Search::Reindexer.new(backend: @backend).call_for_universe(universe)

    written = @backend.calls.select { |type, _| type == :upsert }.flat_map { |_, list| list }
    assert_equal universe.id, written.pluck(:universe_id).uniq.sole
    assert_not_includes written.map { |document| document[:id] }, "universe-#{universe.id}"
    assert_operator summary.documents, :>, 0
  end

  test "a universe reindex applies settings, because it may be the first write ever" do
    Search::Reindexer.new(backend: @backend).call_for_universe(universes(:universe_one))

    assert_equal :apply_settings, @backend.calls.first.first
  end

  test "an unconfigured engine stops a universe reindex with an explanation" do
    summary = Search::Reindexer.new(backend: Search::UnavailableBackend.new)
      .call_for_universe(universes(:universe_one))

    assert_equal Search::UnavailableBackend::REASON, summary.unavailable
  end

  # The levels below a universe. A story rename invalidates every stored path
  # beneath it, and the repair has to be bounded to that story: a second story in
  # the same universe keeps its own paths.
  test "a story reindex writes that story's records and not another story's" do
    story = stories(:story_one)

    summary = Search::Reindexer.new(backend: @backend).call_for_story(story)

    written = written_documents
    assert_equal story.id, written.pluck(:story_id).uniq.sole
    assert_not_includes written.map { |document| document[:id] }, "story-#{story.id}"
    assert_operator summary.documents, :>, 0
  end

  test "a story reindex reaches its elements, which store no story of their own" do
    story = stories(:story_one)

    Search::Reindexer.new(backend: @backend).call_for_story(story)

    ids = written_documents.map { |document| document[:id] }
    assert_equal elements_of(story).pluck(:id).sort,
      ids.grep(/\Ascene_element-/).map { |id| id.delete_prefix("scene_element-").to_i }.sort
  end

  # A scene stores nothing but its own Elements, and an Element's hit opens its
  # Scene — so a scene rename is exactly an Element repair.
  test "a scene reindex writes only the elements stored below that scene" do
    scene = scenes(:scene_one)

    summary = Search::Reindexer.new(backend: @backend).call_for_scene(scene)

    ids = written_documents.map { |document| document[:id] }
    assert_equal scene.scene_elements.count, ids.size
    assert ids.all? { |id| id.start_with?("scene_element-") }
    assert_equal scene.scene_elements.count, summary.documents
  end

  test "an unconfigured engine stops a story reindex with an explanation" do
    summary = Search::Reindexer.new(backend: Search::UnavailableBackend.new)
      .call_for_story(stories(:story_one))

    assert_equal Search::UnavailableBackend::REASON, summary.unavailable
  end

  private
    def written_documents
      @backend.calls.select { |type, _| type == :upsert }.flat_map { |_, list| list }
    end

    # An Element stores its Scene, not its Story, so a story reaches its Elements
    # through the scenes it owns.
    def elements_of(story)
      SceneElement.where(scene_id: story.scenes.select(:id))
    end
end
