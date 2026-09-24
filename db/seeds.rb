# Production-safe bootstrap records belong in db/seeds/ and should be idempotent.
# Temporary development data lives under db/data/<universe_slug>/, one directory per universe.
# The demo loading below is transitional and must not be treated as a production seed contract.

# First the production-safe seeds
Dir[Rails.root.join("db/seeds/**/*.rb")].sort.each do |file|
  puts "Loading #{file}"
  load file
end

# Transitional development-only data loader
universes = ["dark", "lotr"]
universes.each do |name|
  file = Rails.root.join("db/data/#{name}/#{name}.rb")
  puts "Loading #{file}".yellow
  load file
end