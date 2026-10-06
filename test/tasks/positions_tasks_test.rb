require "test_helper"

# The `positions:*` commands, at the level a person or a CI job runs them.
#
# The service's own behaviour is held in `test/services/sequence_normalizer_test.rb`. What
# only the task can be wrong about is the part between it and the person: whether a
# report is printed at all, whether it says which of the two things happened, and whether
# a broken database is distinguishable from a clean one **by exit code** rather than only
# by text somebody has to be reading.
class PositionsTasksTest < ActiveSupport::TestCase
  setup do
    self.class.register_positions_tasks
    @story = stories(:story_one)
  end

  # Registers this application's own `lib/tasks/*.rake` definitions, once per process,
  # for the same reason `SearchTasksTest` does it its way: `Rails.application.load_tasks`
  # re-runs the Rakefile and re-loads every bundled gem's rake files, which are not
  # idempotent.
  def self.register_positions_tasks
    require "rake"

    # `positions:*` depends on `:environment`, which is a Rails-provided task. Loading
    # only this application's rake files leaves it undefined, and the environment is
    # already loaded by `test_helper`.
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?("environment")

    return if @positions_tasks_registered || Rake::Task.task_defined?("positions:status")

    Dir[Rails.root.join("lib/tasks/**/*.rake")].sort.each { |task_file| load task_file }
    @positions_tasks_registered = true
  end

  test "registers the four commands" do
    assert Rake::Task.task_defined?("positions:normalize")
    assert Rake::Task.task_defined?("positions:normalize_universe")
    assert Rake::Task.task_defined?("positions:status")
    assert Rake::Task.task_defined?("positions:status_universe")
  end

  # "Nothing printed" and "everything is broken" have to be different answers to a
  # script. Without this the check only helps the person already watching the terminal.
  test "positions:status fails the run when a sequence is not contiguous" do
    displaced = @story.scenes.create!(name: "Displaced", position: 9)

    output, status = run_task("positions:status")

    assert_equal 1, status, "a broken sequence must be a failing exit code, not only a message"
    assert_includes output, "are not contiguous"
    assert_includes output, "would move"
    assert_equal 9, displaced.reload.position
  end

  test "positions:status succeeds and says so once every sequence is contiguous" do
    SequenceNormalizer.new.call

    output, status = run_task("positions:status")

    assert_equal 0, status
    assert_includes output, "every sequence is contiguous"
  end

  # The check must not write: it is the thing a CI job runs, and a check that quietly
  # repairs would make a failing build look like a passing one.
  test "positions:status writes nothing" do
    displaced = @story.scenes.create!(name: "Displaced", position: 9)

    run_task("positions:status")

    assert_equal 9, displaced.reload.position
  end

  test "positions:normalize repairs and says that it did" do
    displaced = @story.scenes.create!(name: "Displaced", position: 9)

    output, status = run_task("positions:normalize")

    assert_equal 0, status
    assert_includes output, 'Scene "Displaced"'
    assert_match(/moved \d+ record\(s\)/, output)
    assert_not_includes output, "would move",
      "a repairing run says what it moved, not what it would have moved"
    # Its index in the whole story sequence, not zero: the fixtures hold the slots
    # before it, and the command renumbers the whole sequence.
    assert_equal @story.scenes.reorder(:position, :id).to_a.index(displaced), displaced.reload.position
  end

  test "the per-universe commands refuse a slug no universe has" do
    output, status = run_task("positions:status_universe", "no-such-universe")

    assert_equal 1, status
    assert_includes output, "No universe has the slug"
  end

  test "the per-universe check scopes the report to that universe" do
    universes(:universe_two).locations.create!(name: "Elsewhere", position: 4)

    output, = run_task("positions:status_universe", universes(:universe_one).slug)

    assert_not_includes output, "Elsewhere"
  end

  private

    # A Rake task refuses to run twice in one process, and this file runs the same
    # tasks in every test, so each invocation is re-enabled first. Arguments go to
    # `invoke`, not to the lookup: `Rake::Task["task[arg]"]` is a lookup failure.
    #
    # Both streams are swapped by hand rather than with `capture_io` for two reasons: a
    # task that `abort`s raises `SystemExit` from inside the block, which `capture_io`
    # would let through and lose the output written before it; and `abort` writes its
    # message to stderr, which is where a refusal a person needs to read will be.
    def run_task(name, *arguments)
      Rake::Task[name].reenable
      original_out = $stdout
      original_err = $stderr
      buffer = StringIO.new
      status = 0

      begin
        $stdout = buffer
        $stderr = buffer
        Rake::Task[name].invoke(*arguments)
      rescue SystemExit => exit
        status = exit.status
      ensure
        $stdout = original_out
        $stderr = original_err
      end

      [ buffer.string, status ]
    end
end
