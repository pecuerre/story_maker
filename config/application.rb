require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module UniverseMaker
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    #
    # The two files named here are the request pipeline's, and they are ignored
    # because their initializers `require` them: the main autoloader is set up
    # *after* `config/initializers` run, so a constant the pipeline needs at boot
    # cannot come from it. `lib/password_reset_path_filter.rb` is ignored for the
    # same reason and has been since it was written.
    config.autoload_lib(ignore: %w[assets tasks password_reset_path_filter request_log_middleware error_tracking])

    # The two locales this application ships. `en` is the default and the locale
    # every other locale falls back to, so a page is never blocked by a missing
    # translation. The active locale for a request is a browser-owned preference
    # (`AppLocale`), not a `User` column and not a universe setting — the same
    # trade ADR 0013 made for the theme. See ADR 0016.
    config.i18n.available_locales = %i[en es]
    config.i18n.default_locale = :en

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
