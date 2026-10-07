module Search
  # Reads one engine task, so a refusal that arrives *after* the write is visible.
  #
  # Meilisearch acknowledges a write with a task and applies it later, so the
  # interesting half of a write is not in the return value. The engine refuses a
  # whole batch over one document it dislikes — an unusable id, a field it will
  # not index — and answers with a task that looks exactly like a successful one
  # until it is read. A caller that discards the task cannot tell a written
  # document from a refused one, and the refusal exists only in the engine's own
  # task log.
  #
  # Both writers read it, and they deliberately disagree about what a refusal
  # means, because they are different kinds of caller: `Search::Reindexer` is a
  # command a person is watching, so it raises `Search::ReindexFailed` rather
  # than report a document count it never wrote; a job is derived data nobody is
  # watching, so it logs and leaves `bin/rails search:reindex` as the repair. This
  # is the reading; what a reader does about it is the caller's own decision.
  #
  # A backend that is not configured has no task to wait for, and neither does the
  # test backend, so a missing task is simply nothing to wait for.
  class TaskWaiter
    def self.call(task)
      new(task).call
    end

    def initialize(task)
      @task = task
    end

    # Returns why the write failed, or nil when the engine applied it — including
    # the case where there was no task to read.
    def call
      return unless awaitable?

      task.await
      return unless refused?

      "#{task.type} failed: #{engine_message}"
    end

    private
      attr_reader :task

      def awaitable?
        task.respond_to?(:await)
      end

      def refused?
        task.respond_to?(:failed?) && task.failed?
      end

      # The engine reports a refusal as a code and a sentence, and the sentence is
      # the one an operator can act on. A task that carries something else is
      # printed as it is rather than guessed at.
      def engine_message
        error = task.error
        return error.to_s unless error.respond_to?(:[])

        error["message"] || error.to_s
      end
  end
end
