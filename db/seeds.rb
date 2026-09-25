# Production-safe bootstrap records belong in db/seeds/ and should be idempotent.
# Disposable development universes live under db/data/<universe_slug>/ and are
# loaded only through the explicit development-only db:demo:* tasks.

Dir[Rails.root.join("db/seeds/**/*.rb")].sort.each do |file|
  puts "Loading #{file}"
  load file
end
