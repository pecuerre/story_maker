namespace :story_interchange do
  desc "Validate a story-interchange source directory without writing anything"
  task :validate, [ :path ] => :environment do |_task, args|
    path = args[:path].presence || ENV["STORY_INTERCHANGE_PATH"].presence

    unless path
      abort "Usage: bin/rails 'story_interchange:validate[/path/to/source]' " \
        "or STORY_INTERCHANGE_PATH=/path/to/source bin/rails story_interchange:validate"
    end

    report = StoryInterchange.validate(path)

    puts "Universe: #{report.universe_name || "?"} (#{report.universe_slug || "?"})"
    puts "Stories: #{report.stories.map { |story| "#{story[:name]} (#{story[:slug]})" }.join(", ")}" if report.stories.any?

    report.errors.each { |issue| puts "error   #{issue}" }
    report.warnings.each { |issue| puts "warning #{issue}" }

    labels = {
      canon_rules: "Canon rules",
      canon_questions: "Open canon questions",
      characters: "Characters",
      factions: "Factions",
      locations: "Locations",
      items: "Items",
      plots: "Plots",
      chapters: "Chapters",
      scenes: "Scenes"
    }
    labels.each { |kind, label| puts "#{label}: #{report.counts[kind]}" }

    if report.valid?
      puts "Valid with #{report.warnings.size} warning(s)."
    else
      puts "Invalid: #{report.errors.size} error(s), #{report.warnings.size} warning(s)."
      exit 1
    end
  end
end
