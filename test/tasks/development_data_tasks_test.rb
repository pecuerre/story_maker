require "test_helper"

class DevelopmentDataTasksTest < ActiveSupport::TestCase
  setup do
    self.class.register_development_tasks
  end

  # Registers this application's own `lib/tasks/*.rake` definitions, once per process.
  #
  # `Rails.application.load_tasks` is deliberately not used here. It re-runs the Rakefile and
  # re-loads every bundled gem's rake files, and those gem files are not idempotent: the
  # repeated load re-defines `Cssbundling::Tasks::LOCK_FILES` and prints
  # "already initialized constant" warnings from the parallel `bin/rails test` workers.
  def self.register_development_tasks
    return if @development_tasks_registered

    require "rake"
    return if Rake::Task.task_defined?("db:demo:check")

    Dir[Rails.root.join("lib/tasks/**/*.rake")].sort.each { |task_file| load task_file }
    @development_tasks_registered = true
  end

  test "keeps development data out of the production seed path" do
    seeds_source = Rails.root.join("db/seeds.rb").read

    assert_no_match(/db\/data\/.+\.rb/, seeds_source)
    assert_no_match(/Dir\[Rails\.root\.join\("db\/data/, seeds_source)
  end

  test "registers the explicit development data tasks" do
    assert Rake::Task.task_defined?("db:demo:check")
    assert Rake::Task.task_defined?("db:demo:load")
    assert Rake::Task.task_defined?("db:demo:reset")
  end

  test "keeps destructive task guards in the task definition" do
    task_source = Rails.root.join("lib/tasks/db.rake").read

    assert_includes task_source, "Rails.env.development?"
    assert_includes task_source, "CONFIRM_DB_RESET"
    assert_includes task_source, "validate_schema: false"
    assert_not_includes task_source, "Rake::Task[\"db:seed\"]"

    reset_start = task_source.index("task :reset")
    reset_guard = task_source.index("unless Rails.env.development?", reset_start)
    first_reset = task_source.index("Development::DatabaseReset.call", reset_start)
    assert_operator reset_guard, :<, first_reset
  end

  # Both destructive tasks rebuild the database through one shared implementation,
  # so the connection lifecycle that `db:drop` breaks is handled once instead of
  # once per task. Invoking `db:drop`/`db:create`/`db:migrate` in the task itself
  # is what regressed: `db:drop` unlinks the file while the process still holds a
  # connection to it, and the two phases after it then write to the deleted inode.
  test "rebuilds the database through the shared reset in both destructive tasks" do
    task_source = Rails.root.join("lib/tasks/db.rake").read

    assert_equal 2, task_source.scan("Development::DatabaseReset.call").size,
      "both db:demo:reset and db:restart must rebuild through Development::DatabaseReset"
    assert_not_includes task_source, 'Rake::Task["db:drop"]'
    assert_not_includes task_source, 'Rake::Task["db:create"]'
    assert_not_includes task_source, 'Rake::Task["db:migrate"]'

    reset_body = task_source[/task :reset.*?\n    end/m]
    assert_includes reset_body, "Development::UniverseDataLoader.load!(universe: universe)",
      "db:demo:reset must still load the named universe after the database is rebuilt"
  end
end
