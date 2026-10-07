require "test_helper"

# Reading an engine task, which is the only way a refusal the engine accepted and
# then applied becomes visible to the application at all.
#
# `Search::Reindexer` and the two write jobs share this reading and disagree about
# what to do with a refusal, so the shapes below are the ones every caller has to
# survive: no task at all, a task that succeeded, a task the engine failed, and an
# error that is not the message hash the engine normally returns.
class Search::TaskWaiterTest < ActiveSupport::TestCase
  # As the engine answers: `await` returns the refreshed task, and `failed?` and
  # `error` answer about the write it describes.
  Task = Struct.new(:type, :status, :error) do
    def await = self
    def failed? = status == "failed"
  end

  test "a task the engine applied is not a refusal" do
    assert_nil Search::TaskWaiter.call(Task.new(:documentAdditionOrUpdate, "succeeded", nil))
  end

  test "a task the engine failed reports its type and its reason" do
    task = Task.new(:documentAdditionOrUpdate, "failed", { "message" => "invalid_document_id" })

    refusal = Search::TaskWaiter.call(task)

    assert_equal "documentAdditionOrUpdate failed: invalid_document_id", refusal
  end

  # An error that is not the message hash the engine normally sends must not crash
  # the reading: the caller is logging, and losing the reason to a NoMethodError
  # would be worse than a bare `to_s`.
  test "an error that is not a message hash is still reported" do
    task = Task.new(:documentDeletion, "failed", "document_not_found")

    assert_equal "documentDeletion failed: document_not_found", Search::TaskWaiter.call(task)
  end

  # A backend that is not configured, and the test backend, both return no task.
  # Reading one must be nothing to do rather than a NoMethodError on nil.
  test "there being no task is nothing to wait for" do
    assert_nil Search::TaskWaiter.call(nil)
  end

  # The caller decides what a refusal means; this only reads it. A reindex raises
  # `Search::ReindexFailed` and a job logs, and both reach it through here.
  test "the reading raises nothing, so a caller chooses its own consequence" do
    task = Task.new(:documentAdditionOrUpdate, "failed", { "message" => "invalid_document_id" })

    assert_nothing_raised { Search::TaskWaiter.call(task) }
  end
end
