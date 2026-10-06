namespace :positions do
  desc "Renumber every ordered sequence in the database, reporting each record it moves"
  task normalize: :environment do
    summary = SequenceNormalizer.new(output: $stdout).call
    $stdout.puts(summary.to_s)
  end

  desc "Renumber one universe's ordered sequences, e.g. rake positions:normalize_universe[dark]"
  task :normalize_universe, [ :universe_slug ] => :environment do |_task, arguments|
    universe = find_universe(arguments)

    summary = SequenceNormalizer.new(output: $stdout).call_for_universe(universe)
    $stdout.puts("#{universe.name}: #{summary}")
  end

  desc "Report ordered sequences that are not contiguous, without writing anything"
  task status: :environment do
    summary = SequenceNormalizer.new(output: $stdout).check
    $stdout.puts(summary.to_s)
    # A non-zero exit is the point of the check: run from CI or a script, "nothing
    # printed" and "everything is broken" have to be different answers, or the command
    # only helps the person who is already looking at the terminal.
    abort(summary.to_s) if summary.changed?
  end

  desc "Report one universe's ordered sequences without writing, e.g. rake positions:status_universe[dark]"
  task :status_universe, [ :universe_slug ] => :environment do |_task, arguments|
    universe = find_universe(arguments)

    summary = SequenceNormalizer.new(output: $stdout).check_for_universe(universe)
    $stdout.puts("#{universe.name}: #{summary}")
    abort(summary.to_s) if summary.changed?
  end

  def find_universe(arguments)
    slug = arguments[:universe_slug]
    Universe.find_by(slug: slug) || abort("No universe has the slug #{slug.inspect}")
  end
end
