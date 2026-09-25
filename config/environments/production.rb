require "active_support/core_ext/integer/time"

required_env = ->(name) { ENV.fetch(name) { raise "Missing required production environment variable: #{name}" } }

app_host = required_env.call("APP_HOST")
raise "APP_HOST must be a bare hostname" if app_host.include?("://") || app_host.include?("/")

mailer_from = required_env.call("MAILER_FROM")
smtp_address = required_env.call("SMTP_ADDRESS")
smtp_port = begin
  Integer(ENV.fetch("SMTP_PORT", "587"), 10)
rescue ArgumentError
  raise "SMTP_PORT must be an integer"
end
smtp_domain = ENV.fetch("SMTP_DOMAIN", app_host)
smtp_username = ENV["SMTP_USERNAME"]
smtp_password = ENV["SMTP_PASSWORD"]
smtp_authentication = ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym
smtp_starttls_auto = ENV.fetch("SMTP_ENABLE_STARTTLS_AUTO", "true")
smtp_openssl_verify_mode = ENV.fetch("SMTP_OPENSSL_VERIFY_MODE", "peer")

unless %w[true false].include?(smtp_starttls_auto)
  raise "SMTP_ENABLE_STARTTLS_AUTO must be true or false"
end

unless %w[peer verify_peer].include?(smtp_openssl_verify_mode)
  raise "SMTP_OPENSSL_VERIFY_MODE must be peer or verify_peer"
end

if smtp_username.present? ^ smtp_password.present?
  raise "SMTP_USERNAME and SMTP_PASSWORD must be provided together"
end

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # The application is behind a TLS-terminating proxy. Enforce HTTPS in Rails
  # as well so direct HTTP requests cannot carry cookies or reset links.
  config.assume_ssl = true
  config.force_ssl = true
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for background jobs.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Mail delivery is explicit in production; failed jobs must be observable.
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_url_options = { host: app_host, protocol: "https" }
  config.action_mailer.default_options = { from: mailer_from }
  config.action_mailer.smtp_settings = {
    address: smtp_address,
    port: smtp_port,
    domain: smtp_domain,
    user_name: smtp_username,
    password: smtp_password,
    authentication: smtp_authentication,
    enable_starttls_auto: smtp_starttls_auto == "true",
    openssl_verify_mode: smtp_openssl_verify_mode
  }

  # Make the sender available to ApplicationMailer without a placeholder value.
  config.x.mailer_from = mailer_from

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  config.hosts = [ app_host ]
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
