namespace :db do
  desc "Recreate the DB schema and load all data from db/data"
  task restart: :environment do
    Rake::Task["db:drop"].invoke
    Rake::Task["db:create"].invoke
    Rake::Task["db:migrate"].invoke
    Rake::Task["db:seed"].invoke
    Rails.cache.clear
  end
end
