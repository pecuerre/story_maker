# The test environment disables forgery protection by default, so the fast
# request suite is not coupled to token plumbing. The cases that have to prove a
# real token is sent, accepted, and refused wrap their own body in this helper
# instead, which turns protection back on for exactly that window and restores
# the previous setting afterwards.
#
# The flag is read per request by `protect_against_forgery?`, so this works for a
# request test and for the Capybara server thread of a browser test alike.
module ForgeryProtectionTestHelper
  def with_forgery_protection
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  # The token a rendered page publishes for its own JavaScript. Reading it from
  # the page keeps the test honest: it is the same value, from the same place, that
  # a browser would send.
  def csrf_token_from(response_body)
    Nokogiri::HTML(response_body).at_css("meta[name='csrf-token']")&.[]("content")
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include ForgeryProtectionTestHelper
end

# `ActionDispatch::SystemTestCase` inherits from the integration test but is
# loaded through its own hook, so it needs the include as well.
ActiveSupport.on_load(:action_dispatch_system_test_case) do
  include ForgeryProtectionTestHelper
end
