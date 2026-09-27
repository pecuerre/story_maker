require "test_helper"

class SearchTasksTest < ActiveSupport::TestCase
  setup do
    self.class.register_search_tasks
    Search.configuration = Search::Configuration.new(
      url: "http://127.0.0.1:7700", api_key: "local_development_key", environment: "test"
    )
  end

  # Registers this application's own `lib/tasks/*.rake` definitions, once per process,
  # for the same reason `DevelopmentDataTasksTest` does it its way: `Rails.application.load_tasks`
  # re-runs the Rakefile and re-loads every bundled gem's rake files, which are not idempotent.
  def self.register_search_tasks
    require "rake"

    # `search:status` depends on `:environment`, which is a Rails-provided task.
    # Loading only this application's rake files leaves it undefined, and the
    # environment is already loaded by `test_helper`, so an empty task is exactly
    # what invoking one here needs. It is defined before the early return so the
    # order the two task test files happen to load in cannot matter.
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?("environment")

    return if @search_tasks_registered || Rake::Task.task_defined?("search:status")

    Dir[Rails.root.join("lib/tasks/**/*.rake")].sort.each { |task_file| load task_file }
    @search_tasks_registered = true
  end

  test "reports a missing index as a state instead of asking the engine to count it" do
    Search.backend = EngineWithoutAnIndex.new

    output, = run_status

    assert_match(/Index exists:\s+false/, output)
    assert_match(/Documents:\s+\(none/, output)
    assert_match(/search:reindex/, output)
  end

  test "reports the document count once the index exists" do
    Search.backend = EngineWithAnIndex.new

    output, = run_status

    assert_match(/Index exists:\s+true/, output)
    assert_match(/Documents:\s+214/, output)
  end

  test "states an unconfigured engine without asking it anything" do
    Search.configuration = Search::Configuration.new(url: nil, environment: "test")
    Search.backend = Search::UnavailableBackend.new

    output, = run_status

    assert_match(/Available:\s+false/, output)
    assert_match(/Reason:\s+Search is not available/, output)
    assert_no_match(/Documents:/, output)
  end

  private
    def run_status
      # A Rake task refuses to run twice in one process, and this file runs the
      # same task in every test.
      Rake::Task["search:status"].reenable
      capture_io { Rake::Task["search:status"].invoke }
    end

  # A reachable engine whose index has not been created yet: the state a
  # contributor is in the moment after starting Meilisearch and before the first
  # reindex, which is exactly when `search:status` is worth running.
  # `SearchTestBackend` cannot stand in here, because it answers "available?" and
  # "does the index exist?" with the same value.
  class EngineWithoutAnIndex
    def available? = true
    def health = { "status" => "available" }
    def index_exists? = false

    # The real `Search::Client` turns the engine's `index_not_found` into this.
    def stats
      raise Search::Unavailable, "404 Not Found - Index `universe_maker_test` not found."
    end
  end

  class EngineWithAnIndex
    def available? = true
    def health = { "status" => "available" }
    def index_exists? = true
    def stats = { "numberOfDocuments" => 214 }
  end
end
