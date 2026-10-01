require "test_helper"
require "open3"
require "sqlite3"
require "tmpdir"

# Task-level coverage for the development database reset.
#
# The defect this exists for was silent: `db:drop` unlinks the SQLite file while
# the process still holds a connection to it, so the create and migrate that
# follow wrote to the deleted inode and the reset left no database at all. No
# assertion inside the resetting process can see that, because the stale handle
# answers every query from the file that is already gone. So this runs the real
# task in its own process against a database of its own, then reads the file from
# disk with a connection that has nothing to do with the one that wrote it.
#
# The shape under test is deliberately the *single*-database one
# (`DATABASE_URL`, `SKIP_TEST_DATABASE`). The default development configuration
# also creates the test database, and creating it disconnects the development
# pool, which is the accident that used to hide this: the next phase reopened the
# new file by name and the reset looked correct. Only the narrower shape exposes
# the missing connection lifecycle.
class DatabaseResetTest < ActiveSupport::TestCase
  # A table an early create migration makes, and an index the newest migration
  # adds. Checking both ends means a reset that ran some of the migrations is
  # caught, not only one that ran none of them.
  PROBE_TABLE = "universes"
  SESSIONS_INDEX = "index_sessions_on_expires_at"

  test "db:restart rebuilds the database from the migration files" do
    in_scratch_database do |path|
      run_task("db:restart", path)

      assert File.exist?(path), "db:restart left no database file at #{path}"

      with_sqlite(path) do |database|
        assert table_exists?(database, "schema_migrations"),
          "the recreated database has no schema_migrations table, so nothing was migrated into it"

        missing = migration_versions - recorded_versions(database)
        assert_empty missing, "migrations missing from the recreated database: #{missing.join(', ')}"

        assert table_exists?(database, PROBE_TABLE),
          "the recreated database has no #{PROBE_TABLE} table, so the migrations did not reach the file"

        assert object_exists?(database, "index", SESSIONS_INDEX),
          "the recreated database is missing #{SESSIONS_INDEX}, which the newest migration adds"
      end
    end
  end

  test "db:demo:reset rebuilds the database and then loads one universe into it" do
    in_scratch_database do |path|
      run_task("db:demo:reset", path, "UNIVERSE" => "lotr")

      assert File.exist?(path), "db:demo:reset left no database file at #{path}"

      with_sqlite(path) do |database|
        assert table_exists?(database, PROBE_TABLE),
          "the recreated database has no #{PROBE_TABLE} table, so the migrations did not reach the file"

        assert_equal migration_versions, recorded_versions(database),
          "the recreated database does not carry exactly the checked-in migrations"

        assert_equal 1, database.get_first_value("SELECT COUNT(*) FROM universes"),
          "the universe named on the command line was not loaded into the recreated database"
      end
    end
  end

  test "the rebuilt database is built by the migrations rather than by loading the schema dump" do
    in_scratch_database do |path|
      run_task("db:restart", path)

      # `schema_sha1` is written only by `DatabaseTasks.load_schema`, so its
      # absence is the proof that the migrations ran rather than that
      # db/schema.rb was loaded. The recorded versions cannot tell the two apart:
      # loading the dump records every version as applied too.

      with_sqlite(path) do |database|
        # Established first, so the assertion below cannot pass by finding nothing
        # to look at: an empty database has no ar_internal_metadata table either.
        assert table_exists?(database, "ar_internal_metadata"),
          "db:restart left no usable database file at #{path}"

        schema_loads = database.execute(
          "SELECT COUNT(*) FROM ar_internal_metadata WHERE key = 'schema_sha1'"
        ).flatten.map(&:to_i)

        assert_equal [ 0 ], schema_loads,
          "ar_internal_metadata records a schema_sha1, and only DatabaseTasks.load_schema writes one; " \
          "the reset loaded db/schema.rb instead of running the migrations, so an amended migration " \
          "would change nothing on a fresh database"
      end
    end
  end

  private
    # A scratch database of this run's own. `DATABASE_URL` replaces the whole
    # configuration, so the task cannot reach `storage/development.sqlite3` or
    # `storage/test.sqlite3` even by accident.
    def in_scratch_database
      Dir.mktmpdir("database-reset-test") do |dir|
        yield File.join(dir, "reset.sqlite3")
      end
    end

    def run_task(task, path, extra_env = {})
      environment = {
        "RAILS_ENV" => "development",
        "CONFIRM_DB_RESET" => "1",
        "SKIP_TEST_DATABASE" => "1",
        "DATABASE_URL" => "sqlite3:#{path}"
      }.merge(extra_env)

      output, status = Open3.capture2e(environment, "bin/rails", task, chdir: Rails.root.to_s)
      assert status.success?, "#{task} failed:\n#{output}"
    end

    def with_sqlite(path, &block)
      database = SQLite3::Database.new(path)
      block.call(database)
    ensure
      database&.close
    end

    def table_exists?(database, name)
      object_exists?(database, "table", name)
    end

    # Read straight from sqlite_master rather than through Active Record: the
    # point of this file is to inspect the file on disk from a connection that
    # did not write it, and going back through the framework would put the very
    # handle under suspicion back in the path.
    def object_exists?(database, type, name)
      database.get_first_value(
        "SELECT COUNT(*) FROM sqlite_master WHERE type = ? AND name = ?", type, name
      ).to_i.positive?
    end

    # The versions the checked-in migrations declare, read from the files rather
    # than from Active Record, so the check cannot agree with the thing it checks.
    def migration_versions
      Dir[Rails.root.join("db/migrate/*.rb")].map { |file| File.basename(file).split("_").first.to_i }.sort
    end

    def recorded_versions(database)
      database.execute("SELECT version FROM schema_migrations").flatten.map(&:to_i).sort
    end
end
