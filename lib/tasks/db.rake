namespace :db do
  namespace :demo do
    desc "Validate one registered development universe without writing records"
    task :check, [ :universe ] => :environment do |_task, args|
      universe = args[:universe].presence || ENV["UNIVERSE"]
      Development::UniverseDataLoader.check!(universe: universe)
      puts "Development data check passed for #{universe}."
    end

    desc "Load one registered development universe into the development database"
    task :load, [ :universe ] => :environment do |_task, args|
      universe = args[:universe].presence || ENV["UNIVERSE"]
      Development::UniverseDataLoader.load!(universe: universe)
      puts "Development data loaded for #{universe}."
    end

    desc "Drop, recreate, migrate, and load one development universe (requires CONFIRM_DB_RESET=1)"
    task :reset, [ :universe ] => :environment do |_task, args|
      universe = args[:universe].presence || ENV["UNIVERSE"]

      unless Rails.env.development?
        abort "Refusing destructive reset. db:demo:reset is development-only."
      end

      unless ENV["CONFIRM_DB_RESET"] == "1"
        abort "Refusing destructive reset. Set CONFIRM_DB_RESET=1 and UNIVERSE=<registered-universe>."
      end

      Development::UniverseDataLoader.check!(universe: universe, validate_schema: false)
      Rake::Task["db:drop"].invoke
      Rake::Task["db:create"].invoke
      Rake::Task["db:migrate"].invoke
      Development::UniverseDataLoader.load!(universe: universe)
      Rails.cache.clear
      puts "Development database reset and loaded for #{universe}."
    end
  end

  desc "Drop, create, and migrate the development database without loading demo data"
  task restart: :environment do
    unless Rails.env.development? && ENV["CONFIRM_DB_RESET"] == "1"
      abort "Refusing database reset. Run only in development with CONFIRM_DB_RESET=1."
    end

    Rake::Task["db:drop"].invoke
    Rake::Task["db:create"].invoke
    Rake::Task["db:migrate"].invoke
    Rails.cache.clear
    puts "Development database reset without demo data."
  end
end
