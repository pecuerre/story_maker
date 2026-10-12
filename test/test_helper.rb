ENV["RAILS_ENV"] ||= "test"
# Before `config/environment`: SimpleCov measures what it loads after it starts.
require_relative "coverage_helper"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/forgery_protection_test_helper"
require_relative "test_helpers/log_test_helper"
require_relative "test_helpers/query_count_test_helper"
require_relative "test_helpers/throttle_test_helper"
require_relative "support/search_test_backend"
require_relative "support/photo_test_helper"
require_relative "support/photo_dimensions"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Every test starts with an empty cache, because the test environment's cache
    # is a counting `:memory_store` rather than a `:null_store`
    # (`config/environments/test.rb`) and a `:memory_store` outlives a single
    # test. Without this, two kinds of state leak between tests in one process:
    #
    # - **rate-limit counters.** The sign-in and password-reset limits count per
    #   remote IP, and every request test arrives from `127.0.0.1`, so eleven
    #   sign-in attempts anywhere in the suite would refuse the sign-in in an
    #   unrelated test that runs afterwards.
    # - **menu counts.** A cached sidebar or navbar count written by one test is
    #   still cached in the next, which is how a test asserting one nav item
    #   finds two.
    #
    # Clearing rather than restoring a saved store keeps what the suite had under
    # `:null_store` — nothing cached across tests — while letting a limit count
    # within one test. Tests that want to assert on caching install their own
    # store (see `test/models/menu_count_cache_test.rb`).
    setup { Rails.cache.clear }

    # Search indexing is queued, so a test needs to be able to ask what a save
    # would have written. The test environment uses the `:test` queue adapter
    # (see `config/environments/test.rb`), so nothing runs and nothing needs an
    # engine.
    include ActiveJob::TestHelper

    include SearchTestHelper
  end
end
