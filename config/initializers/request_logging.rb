# One structured request event per request, written *inside*
# `Rails::Rack::Logger` so it carries that request's log tags (the `request_id`
# tag production configures), and inside `Rails::Rack::SilenceRequest` so
# `config.silence_healthcheck_path` keeps the health check out of this log as well
# as the framework's. `RequestLogMiddleware` documents the rest of the placement.
#
# The file is required rather than autoloaded because `config/initializers` runs
# before the main autoloader is set up, and `config/application.rb` builds the
# middleware stack before initializers run — neither is a moment at which an
# autoloadable constant can be named. `config.autoload_lib`'s ignore list is what
# keeps the required file from being managed twice.
require Rails.root.join("lib/request_log_middleware")

Rails.application.config.middleware.insert_after Rails::Rack::Logger, RequestLogMiddleware
