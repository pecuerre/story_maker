require "test_helper"
require "fileutils"
require "tmpdir"

# The command-line entry point is a thin caller of `StoryInterchange::Import`.
# These cases run it, so the registration, the destructive gate, and the preview
# it prints are exercised rather than only described.
class StoryInterchangeTasksTest < ActiveSupport::TestCase
  FIXTURE = Rails.root.join("test/fixtures/files/story_interchange/synthetic-universe")
  CONFIRMATION = "CONFIRM_STORY_INTERCHANGE_IMPORT"

  setup do
    load_tasks
    @temporary_directory = Dir.mktmpdir("story-interchange-task-test")
    @root = File.join(@temporary_directory, "synthetic-universe")
    FileUtils.cp_r(FIXTURE, @root)
    @operator = users(:platform_operator)
  end

  teardown do
    FileUtils.remove_entry(@temporary_directory) if File.directory?(@temporary_directory)
    ENV.delete(CONFIRMATION)
    Rake::Task["story_interchange:import"].reenable
  end

  test "registers the import and validate tasks" do
    assert Rake::Task.task_defined?("story_interchange:import")
    assert Rake::Task.task_defined?("story_interchange:validate")
  end

  test "imports with the destructive confirmation and prints the run" do
    ENV[CONFIRMATION] = "1"
    output = nil

    assert_difference -> { Universe.where(slug: "synthetic-universe").count }, 1 do
      output, _error = capture_io { invoke }
    end

    assert_includes output, "Universe: Synthetic Universe (synthetic-universe)"
    assert_includes output, "Canon rules: 3, 1 reported not written (O-I1)"
    assert_includes output, "Characters: 1, 9 reported not written"
    assert_includes output, "Factions: 1, 7 reported not written"
    assert_includes output, "Locations: 1, 7 reported not written"
    assert_includes output, "Items: 1, 4 reported not written"
    assert_includes output, "Stories: 1"
    assert_includes output, "Plots: 1, 11 reported not written"
    assert_includes output, "Imported Synthetic Universe (synthetic-universe)."
    assert_includes output, "Canon rules: 3 written, 1 skipped (O-I1)"
    assert_includes output, "Characters: 1 written, 9 skipped"
    assert_includes output, "Factions: 1 written, 7 skipped"
    assert_includes output, "Locations: 1 written, 7 skipped"
    assert_includes output, "Items: 1 written, 4 skipped"
    assert_includes output, "Stories: 1 written"
    assert_includes output, "Plots: 1 written, 11 skipped"
  end

  test "refuses to write without the confirmation" do
    error = assert_raises(SystemExit) { capture_io { invoke } }

    assert_equal 1, error.status
    assert_equal 0, Universe.where(slug: "synthetic-universe").count
  end

  test "refuses a target with an open draft before asking for confirmation" do
    existing = StoryInterchange::Import.new(@root, owner: @operator).call.universe
    Draft.create!(user: @operator, universe: existing)
    ENV[CONFIRMATION] = "1"

    error = assert_raises(SystemExit) { capture_io { invoke } }

    assert_equal 1, error.status
    assert_not existing.reload.deleted?
  end

  private
    def invoke
      Rake::Task["story_interchange:import"].invoke(@root, @operator.email_address)
    end

    # The application's own rake tasks are registered by `Rails.application.load_tasks`,
    # which re-runs bundled gem task files that are not idempotent. This loads only
    # the file under test, with the environment dependency it declares.
    def load_tasks
      require "rake"
      Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
      return if Rake::Task.task_defined?("story_interchange:import")

      load Rails.root.join("lib/tasks/story_interchange.rake")
    end
end
