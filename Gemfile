source "https://rubygems.org"

# Rails stuff
gem "rails", "~> 8.0.2"
gem "propshaft"
gem "sqlite3", ">= 2.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "cssbundling-rails"
gem "jbuilder"

# Security Stuff
# gem "bcrypt", "~> 3.1.7" # Use Active Model has_secure_password

# Performance and Caching
gem "solid_cache" # Use Solid Cache for Rails.cache
gem "solid_queue" # Use Solid Queue for Active Job
gem "solid_cable" # Use Solid Cable for Action Cable
gem "bootsnap", require: false # Speed up boot time by caching expensive operations

# Extra gems for Rails
gem "tzinfo-data", platforms: %i[ windows jruby ] # Timezone data for Windows and JRuby
# gem "image_processing", "~> 1.2" # Use Active Storage for image processing

# Deployment and Production
gem "kamal", require: false # Kamal for deployment automation with Docker
gem "thruster", require: false # Thruster for fast Rails production deployments

# Testing and Development
group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false # Static analysis security tool for Ruby on Rails
  gem "rubocop-rails-omakase", require: false # RuboCop for Rails code style and best practices
end
group :development do
  gem "web-console" # Interactive console in the browser
  gem "byebug" # Debugging tool for Ruby
end
group :test do
  gem "capybara" # Integration testing framework
  gem "selenium-webdriver" # Driver for Capybara to run tests in a real browser
  gem "rails-controller-testing" # Provides additional testing methods for Rails controllers
end

# PQR Stuff
gem "colored"
