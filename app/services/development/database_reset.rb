module Development
  # Recreates the development database from the migration files, in one process.
  #
  # The obvious sequence — `db:drop`, `db:create`, `db:migrate` — is wrong in two
  # ways, and both fail silently: the task reports success and leaves either no
  # database at all or one built from a schema dump rather than from the
  # migrations.
  #
  # 1. **`db:drop` unlinks the file while this process still holds a connection
  #     to it.** SQLite keeps the deleted inode alive for every open handle, so
  #     the phases that follow write to a file that no longer has a name and the
  #     recreated database is empty. A default development setup hides this by
  #     accident: `db:create` also creates the *test* database, and connecting to
  #     that second file disconnects the first, so the next phase happens to
  #     reopen the new development file. Remove the second database — a
  #     `DATABASE_URL`, or `SKIP_TEST_DATABASE` — and nothing reconnects, so the
  #     reset produces no database and every later command reads an empty one.
  #     Each phase therefore gets its own connection lifecycle: nothing holds a
  #     handle to the file being unlinked, and the next phase opens the file by
  #     name instead of inheriting a handle to the deleted inode.
  #
  # 2. **On a database with no `schema_migrations` table, `db:migrate` loads
  #     `db/schema.rb` instead of running the migrations.** Rails 8.1's
  #     `DatabaseTasks.initialize_database` reads a missing table as "this
  #     database has no schema yet" and loads the dump, which records every
  #     version as applied. An amended migration then changes nothing on a fresh
  #     database, the regenerated `db/schema.rb` keeps the old shape, and the
  #     mismatch surfaces much later as an unknown column in a form or a
  #     manifest. `skip_initialize` asks Active Record for the migrations
  #     themselves.
  #
  # The verification at the end is what makes both failures loud. It reads the
  # database through a connection opened after the last handle was released,
  # because an inherited one can still be sitting on the deleted inode and would
  # answer from a database that no longer exists on disk.
  class DatabaseReset
    class Error < StandardError; end

    SCHEMA_MIGRATIONS_TABLE = "schema_migrations"

    # A table an early create migration makes and every schema has. Proving it
    # exists is what catches "the migrations reached the deleted inode instead of
    # the file": the recorded versions cannot, because the deleted inode carries
    # a complete `schema_migrations` table too.
    PROBE_TABLE = "universes"

    def self.call(...)
      new(...).call
    end

    def initialize(environment: Rails.env)
      @environment = environment
    end

    # Drops, recreates, and migrates every database configured for the current
    # environment, then proves the result. Returns self.
    def call
      drop!
      create!
      migrate!
      verify!
      self
    end

    private
      attr_reader :environment

      # The scope `db:migrate` covers: the databases configured for the current
      # environment. Dropping and creating go through Active Record's own
      # `drop_current`/`create_current` rather than a list built here, because
      # those widen the scope to the test database in development and that
      # difference belongs to Active Record's task contract, not to a list this
      # class re-derives.
      def db_configs
        ActiveRecord::Base.configurations.configs_for(env_name: environment)
      end

      # The protected-environment check `db:drop` runs connects before it
      # unlinks, so a handle to the deleted file exists again by the time it
      # returns. Releasing has to happen *after* the drop, not instead of it.
      def drop!
        release_connections!
        ActiveRecord::Tasks::DatabaseTasks.drop_current(environment)
      ensure
        release_connections!
      end

      def create!
        release_connections!
        ActiveRecord::Tasks::DatabaseTasks.create_current(environment)
      end

      def migrate!
        db_configs.each do |db_config|
          ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: environment, name: db_config.name) do
            ActiveRecord::Tasks::DatabaseTasks.migrate(skip_initialize: true)
          end
        end
        dump_schema!
      end

      # The dump is regenerated in this process because it is what CI compares
      # against the migrations, and `db:migrate` does the same through `db:_dump`.
      def dump_schema!
        db_configs.each { |db_config| ActiveRecord::Tasks::DatabaseTasks.dump_schema(db_config) }
      end

      # Only the current environment's databases, which is the development database.
      # `db:drop` and `db:create` also empty the test database in development —
      # a scope question that belongs to the reset as a whole — and an empty test
      # database has nothing to prove.
      def verify!
        db_configs.each { |db_config| verify_database!(db_config) }
      end

      def verify_database!(db_config)
        path = database_path(db_config)
        raise Error, "#{path} does not exist; the reset produced no database" unless File.exist?(path)

        # Released first, so the connection `with_temporary_connection` checks
        # out is opened by name against the file on disk rather than reused from
        # the handle that was pointing at the unlinked inode.
        release_connections!
        ActiveRecord::Tasks::DatabaseTasks.with_temporary_connection(db_config) do |connection|
          unless connection.table_exists?(SCHEMA_MIGRATIONS_TABLE)
            raise Error, "#{path} has no #{SCHEMA_MIGRATIONS_TABLE} table; nothing was migrated into it"
          end

          missing = expected_migration_versions - recorded_migration_versions(connection)
          raise Error, "#{path} is missing migrations: #{missing.join(', ')}" if missing.any?

          unless connection.table_exists?(PROBE_TABLE)
            raise Error, "#{path} has no #{PROBE_TABLE} table; the migrations did not reach the file"
          end
        end
      end

      def recorded_migration_versions(connection)
        connection.select_values("SELECT version FROM #{SCHEMA_MIGRATIONS_TABLE}").map(&:to_i)
      end

      # Read from the migration files rather than from Active Record's own list,
      # so the check cannot agree with the thing it is checking.
      def expected_migration_versions
        ActiveRecord::Tasks::DatabaseTasks.migrations_paths.flat_map do |path|
          Dir[File.join(path, "*.rb")].map { |file| File.basename(file).split("_").first.to_i }
        end.uniq.sort
      end

      def database_path(db_config)
        database = db_config.database.to_s
        File.absolute_path?(database) ? database : Rails.root.join(database).to_s
      end

      def release_connections!
        ActiveRecord::Base.connection_handler.clear_all_connections!
      end
  end
end
