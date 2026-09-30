ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/forgery_protection_test_helper"
require_relative "support/search_test_backend"
require_relative "support/photo_test_helper"
require_relative "support/photo_dimensions"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Search indexing is queued, so a test needs to be able to ask what a save
    # would have written. The test environment uses the `:test` queue adapter
    # (see `config/environments/test.rb`), so nothing runs and nothing needs an
    # engine.
    include ActiveJob::TestHelper

    include SearchTestHelper
  end
end
