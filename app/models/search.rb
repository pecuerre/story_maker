# The one entry point to the search engine, so nothing else in the application
# constructs a client or knows whether one exists.
#
# `Search.backend` is the entire surface: a real `Search::Client` when the engine
# is configured, and `Search::UnavailableBackend` when it is not. Callers
# therefore have exactly one code path. A missing or broken engine is reported
# as unavailable rather than quietly replaced by a second, subtly different
# search — a fallback engine would mean two ranking behaviours, two sets of
# results for the same query, and no way to tell a user which one they saw.
#
# The top bar carries the search box, so a search happens on every page. A
# search that raises would take the page down with it, which is why "unavailable"
# is a first-class answer here instead of an exception a caller must guess to
# rescue.
module Search
  # Raised when the engine is not configured, not reachable, or refused the
  # request. Callers turn it into a stated state, never into a failed page.
  class Unavailable < StandardError; end

  # Raised when the engine accepted a write and then refused it — a document it
  # will not index, or a setting it rejected. A maintenance command must not
  # report success in that case, and must not report a document count it never
  # wrote either.
  class ReindexFailed < StandardError; end

  class << self
    attr_writer :configuration, :backend

    def configuration
      @configuration ||= Configuration.from_env
    end

    def backend
      @backend ||= if configuration.available?
        Client.new(configuration)
      else
        UnavailableBackend.new
      end
    end

    # Search state is memoized per process because it is derived from the
    # environment, which does not change while the application runs. Tests and
    # the search tasks reset it explicitly instead of stubbing internals.
    def reset!
      @configuration = nil
      @backend = nil
    end
  end
end
