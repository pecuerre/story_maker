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

  desc "Import a story-interchange source, replacing the universe its directory names (destructive)"
  task :import, [ :path, :owner ] => :environment do |_task, args|
    path = args[:path].presence || ENV["STORY_INTERCHANGE_PATH"].presence
    owner_email = args[:owner].presence || ENV["STORY_INTERCHANGE_OWNER"].presence

    unless path && owner_email
      abort "Usage: bin/rails 'story_interchange:import[/path/to/source,owner@example.com]' " \
        "or STORY_INTERCHANGE_PATH=/path/to/source STORY_INTERCHANGE_OWNER=owner@example.com " \
        "bin/rails story_interchange:import"
    end

    owner = User.find_by(email_address: owner_email)
    abort "No user with the email address #{owner_email}." unless owner

    import = StoryInterchange::Import.new(path, owner: owner)
    plan = import.plan

    puts "Universe: #{plan.name || "?"} (#{plan.slug || "?"})"
    puts plan.existing? ? "Replaces the existing universe of that slug." : "Creates a new universe."
    plan.slices.each do |slice|
      line = "#{I18n.t(slice.label_key)}: #{slice.preview(plan.report)}"
      reported = slice.reported(plan.report)
      line += ", #{reported.size} reported not written (#{reported.to_sentence})" if reported.any?
      puts line
    end

    plan.report.errors.each { |issue| puts "error   #{issue}" }
    plan.report.warnings.each { |issue| puts "warning #{issue}" }

    abort "Refusing: the source has #{plan.report.errors.size} error(s)." unless plan.valid?

    unless plan.safe?
      plan.open_drafts.each { |draft| puts "open draft #{draft.id} by #{draft.user.email_address}" }
      plan.other_members.each { |member| puts "member #{member.email_address}" }
      abort "Refusing: the existing universe has open drafts or members other than #{owner.email_address}."
    end

    puts "Records created in the app for this universe are lost. No other universe is touched."
    unless ENV["CONFIRM_STORY_INTERCHANGE_IMPORT"] == "1"
      abort "Refusing to write without confirmation. Re-run with CONFIRM_STORY_INTERCHANGE_IMPORT=1."
    end

    result = import.call

    puts "Imported #{result.universe.name} (#{result.universe.slug})."
    result.outcomes.each do |outcome|
      line = "#{I18n.t(outcome.label_key)}: #{outcome.created} written"
      line += ", #{outcome.skipped.size} skipped (#{outcome.skipped.to_sentence})" if outcome.skipped?
      puts line
    end
  end
end
