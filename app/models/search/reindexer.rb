module Search
  # Rebuilds the index from the database.
  #
  # This is the bootstrap and the recovery path: after a fresh engine is started,
  # after a restore, or after any period in which queued writes could not reach
  # it. It clears the index before writing, so documents whose records were
  # deleted while the engine was unreachable do not survive a rebuild.
  #
  # Order matters. A filtered search only works once `filterable_attributes` has
  # been applied, and Meilisearch refuses settings for an index that does not
  # exist yet — so the index is created, its settings applied, and only then are
  # documents written. Every task is awaited, because this runs from a terminal
  # where "finished" has to mean searchable.
  class Reindexer
    BATCH_SIZE = 500

    Summary = Data.define(:documents, :models, :unavailable) do
      def to_s
        return "search is not available: #{unavailable}" if unavailable

        "indexed #{documents} document(s) from #{models} model(s)"
      end
    end

    def initialize(backend: Search.backend, output: nil)
      @backend = backend
      @output = output
    end

    # Returns a `Summary`, or a summary that says the engine is not configured
    # rather than raising: this is a maintenance command, and a person running it
    # needs an explanation, not a backtrace.
    def call
      unless backend.available?
        return Summary.new(documents: 0, models: 0, unavailable: Search::UnavailableBackend::REASON)
      end

      create_index
      await backend.apply_settings
      await backend.remove_all

      documents = 0
      each_batch do |batch|
        await backend.upsert(batch)
        documents += batch.size
        report "indexed #{documents} document(s)"
      end

      Summary.new(documents: documents, models: Search::Registry::MODELS.size, unavailable: nil)
    end

    # A single universe, used after its slug changes: every document under a
    # universe carries that universe's slug in its stored path.
    def call_for_universe(universe)
      rewrite(Search::Registry.relations_for(universe))
    end

    # A single story, used after its slug changes: a Section, a Scene, and their
    # tags and Elements all carry that story's slug in their stored path, so they
    # are the records a rename leaves pointing at nothing.
    def call_for_story(story)
      rewrite(Search::Registry.relations_for_story(story))
    end

    # A single scene, used after its slug changes: only its Elements store its
    # path, because an Element's hit opens the scene that owns it.
    def call_for_scene(scene)
      rewrite(Search::Registry.relations_for_scene(scene))
    end

    private
      attr_reader :backend, :output

      # One owner, not the whole index. The relations it holds are written in
      # batches, and the settings are applied first because a repair may be the
      # first write this engine has ever seen.
      def rewrite(relations)
        unless backend.available?
          return Summary.new(documents: 0, models: 0, unavailable: Search::UnavailableBackend::REASON)
        end

        await backend.apply_settings
        documents = 0
        relations.each do |relation|
          relation.find_in_batches(batch_size: BATCH_SIZE) do |batch|
            await backend.upsert(batch.map(&:search_document))
            documents += batch.size
          end
        end
        Summary.new(documents: documents, models: relations.size, unavailable: nil)
      end

      def create_index
        backend.create_index
      rescue Meilisearch::ApiError => error
        # An index that already exists is the normal case: a reindex replaces its
        # contents rather than starting from nothing. Any other refusal is real.
        raise unless error.code == "index_already_exists"
      end

      def each_batch
        Search::Registry::MODELS.each do |model|
          model.find_in_batches(batch_size: BATCH_SIZE) do |relation|
            yield relation.map(&:search_document)
          end
        end
      end

      # A task that *fails* is the important half: the engine refuses a whole
      # batch over one document it dislikes — an unusable id, a field it will not
      # index — and answers with a task that looks exactly like a successful one
      # until it is read. Here a refusal raises, because a command must not report
      # a document count it never wrote; `Search::TaskWaiter` owns the reading, and
      # the two write jobs use it too.
      def await(task)
        refusal = TaskWaiter.call(task)
        raise ReindexFailed, refusal if refusal
      end

      def report(message)
        output&.puts(message)
      end
  end
end
