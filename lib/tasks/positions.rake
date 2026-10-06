namespace :positions do
  desc "Renumber every ordered sequence in the database, reporting each record it moves"
  task normalize: :environment do
    summary = SequenceNormalizer.new(output: $stdout).call
    $stdout.puts(summary.to_s)
  end

  desc "Renumber one universe's ordered sequences, e.g. rake positions:normalize_universe[dark]"
  task :normalize_universe, [ :universe_slug ] => :environment do |_task, arguments|
    universe = Universe.find_by(slug: arguments[:universe_slug])
    abort("No universe has the slug #{arguments[:universe_slug].inspect}") if universe.nil?

    summary = SequenceNormalizer.new(output: $stdout).call_for_universe(universe)
    $stdout.puts("#{universe.name}: #{summary}")
  end
end
