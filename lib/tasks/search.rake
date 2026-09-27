namespace :search do
  desc "Rebuild the search index from the database"
  task reindex: :environment do
    summary = Search::Reindexer.new(output: $stdout).call
    $stdout.puts(summary.to_s)
    # A summary that reports an unconfigured engine is a failure for a command
    # whose only job is to write to it: a person running this needs to know it
    # did not do what they asked.
    abort(summary.to_s) if summary.unavailable
  end

  desc "Re-index one universe, e.g. rake search:reindex_universe[the-dark]"
  task :reindex_universe, [ :universe_slug ] => :environment do |_task, arguments|
    universe = Universe.find_by(slug: arguments[:universe_slug])
    abort("No universe has the slug #{arguments[:universe_slug].inspect}") if universe.nil?

    summary = Search::Reindexer.new(output: $stdout).call_for_universe(universe)
    $stdout.puts("#{universe.name}: #{summary}")
    abort(summary.to_s) if summary.unavailable
  end

  desc "Report the search engine's configuration, index, and health"
  task status: :environment do
    configuration = Search.configuration
    backend = Search.backend

    $stdout.puts("URL:            #{configuration.url || "(not set)"}")
    $stdout.puts("API key:        #{configuration.api_key ? "set" : "(not set)"}")
    $stdout.puts("Index:          #{configuration.index_name}")
    $stdout.puts("Available:      #{backend.available?}")

    unless backend.available?
      $stdout.puts("Reason:         #{backend.reason}")
      next
    end

    $stdout.puts("Health:         #{backend.health.inspect}")

    # The document count is a question about an index, and before the first
    # reindex there is no index to count: the engine answers `stats` for a
    # missing index with `index_not_found`, which `Search::Client` honestly
    # re-raises. So the state is reported instead, because this is the command
    # a person is told to run first when search returns nothing — it has to
    # answer that question, not abort on it.
    if backend.index_exists?
      $stdout.puts("Index exists:   true")
      $stdout.puts("Documents:      #{backend.stats&.fetch("numberOfDocuments", "(unknown)")}")
    else
      $stdout.puts("Index exists:   false")
      $stdout.puts("Documents:      (none — the index is created by bin/rails search:reindex)")
    end
  end
end
