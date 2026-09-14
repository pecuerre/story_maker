# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# First the seeds
Dir[Rails.root.join("db/seeds/**/*.rb")].sort.each do |file|
  puts "Loading #{file}"
  load file
end

# Then the data
universes = ["dark", "lotr"]
universes.each do |name|
  file = Rails.root.join("db/data/#{name}/#{name}.rb")
  puts "Loading #{file}".yellow
  load file
end