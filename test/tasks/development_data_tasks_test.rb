require "test_helper"

class DevelopmentDataTasksTest < ActiveSupport::TestCase
  setup do
    require "rake"
    Rails.application.load_tasks unless Rake::Task.task_defined?("db:demo:check")
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
    first_drop = task_source.index('Rake::Task["db:drop"]', reset_start)
    assert_operator reset_guard, :<, first_drop
  end
end
