require "test_helper"

# Error tracking is optional, and the question that matters is what it does in each
# of its three states: off, on with a collector it cannot reach, and on with one it
# can. The rules that decide those are a privacy policy and a volume policy, so they
# are pinned here rather than left in the module's comments.
class ErrorTrackingTest < ActiveSupport::TestCase
  # Plain HTTP is refused, so a value that reaches a socket in these examples has to
  # be a name rather than an address, and delivery itself is exercised by handing
  # `Net::HTTP` a stub — see `ErrorTrackingDeliveryTest`.
  UNREACHABLE_DSN = "https://collector.invalid:9/api/1".freeze

  setup do
    ErrorTracking.reset!
    @previous_dsn = ENV[ErrorTracking::DSN_VARIABLE]
    ENV.delete(ErrorTracking::DSN_VARIABLE)
  end

  teardown do
    ENV[ErrorTracking::DSN_VARIABLE] = @previous_dsn
    ErrorTracking.reset!
  end

  test "nothing is initialized and nothing is sent when no DSN is configured" do
    # The gate itself: no DSN means no client, no socket, no dependency. A test that
    # proved it by reaching the network would prove the opposite.
    assert_not ErrorTracking.enabled?
    assert_nil ErrorTracking.dsn

    log = capture_log do
      ErrorTracking.record(ArgumentError.new("no collector"), handled: false, severity: :error, source: "test")
    end

    assert_includes log, "no collector"
  end

  test "a configured DSN enables forwarding" do
    ENV[ErrorTracking::DSN_VARIABLE] = "https://collector.example/api/1"
    ErrorTracking.reset!

    assert ErrorTracking.enabled?
    assert_equal "https://collector.example/api/1", ErrorTracking.dsn.to_s
  end

  test "a DSN that is not an https URL with a host and a path is refused rather than used" do
    # A collector reached in the clear would publish this application's failures to
    # whoever can read the path between here and there, so the safe behaviour is to
    # refuse to start rather than to guess.
    [ "http://collector.example/api/1", "collector.example/api/1", "https://collector.example",
      "not a url at all" ].each do |value|
      ENV[ErrorTracking::DSN_VARIABLE] = value
      ErrorTracking.reset!

      error = assert_raises(RuntimeError, "#{value.inspect} was accepted as a collector") { ErrorTracking.dsn }

      assert_includes error.message, ErrorTracking::DSN_VARIABLE
      assert_includes error.message, "https"
    end
  end

  test "an unhandled error is logged as a structured event" do
    log = capture_log do
      ErrorTracking.record(ArgumentError.new("boom"), handled: false, severity: :error, source: "test")
    end
    event = log_events(log, "error").sole

    assert_equal "error", event["event"]
    assert_equal "ArgumentError", event["error_class"]
    assert_equal "boom", event["message"]
    assert_equal false, event["handled"]
    assert_equal "error", event["severity"]
    assert_equal "test", event["source"]
    assert_predicate event["occurred_at"], :present?
  end

  test "an error the application recovered from is logged as a warning" do
    log = capture_log do
      ErrorTracking.record(ArgumentError.new("recovered"), handled: true, severity: :warning, source: "test")
    end

    assert_includes log, "WARN"
    assert_includes log, "recovered"
  end

  test "an error's backtrace is carried, bounded, and redacted" do
    error = ArgumentError.new("boom")
    error.set_backtrace([ "app/models/thing.rb:1:in `run'", "token=abc123 in here" ] +
      Array.new(40) { |index| "frame#{index}" })

    payload = ErrorTracking.build_payload(error, handled: false, severity: :error, source: "test")

    assert_equal ErrorTracking::BACKTRACE_FRAMES, payload[:backtrace].size
    assert_equal "app/models/thing.rb:1:in `run'", payload[:backtrace].first
    assert_includes payload[:backtrace].second, "token=[FILTERED]"
  end

  test "a long message is capped" do
    payload = ErrorTracking.build_payload(RuntimeError.new("x" * 5_000), handled: false, severity: :error, source: "test")

    assert_equal ErrorTracking::MESSAGE_LIMIT, payload[:message].length
  end

  test "a message quoting a credential, an address, or a key is redacted" do
    # `token=…` is the shape `config.filter_parameters` already governs; the address
    # and the URL credentials are the two it does not describe.
    payload = ErrorTracking.build_payload(
      RuntimeError.new("deliver to https://user:hunter2@collector.example/api failed for " \
        "writer@example.com with token=abc123 and password: hunter2"),
      handled: false, severity: :error, source: "test"
    )

    assert_equal "deliver to https://[FILTERED]@collector.example/api failed for " \
      "[FILTERED] with token=[FILTERED] and password: hunter2", payload[:message]
  end

  test "an error report carries no request beyond the published correlation keys" do
    # The privacy rule as an assertion: a context holding a session, a request, and
    # an account cannot publish any of it, because the payload reads named keys only.
    context = {
      request_id: "abc", request_path: "/u/one/characters", request_status: 500,
      session: { user_id: 1 }, current_user_id: 1, cookies: "secret", user_agent: "Firefox"
    }

    payload = ErrorTracking.build_payload(ArgumentError.new("boom"), handled: false, severity: :error,
      context: context, source: "test")

    assert_equal({ request_id: "abc", request_path: "/u/one/characters", request_status: 500 }, payload[:request])
    refute_includes payload.to_json, "secret"
    refute_includes payload.to_json, "Firefox"
  end

  test "the module is subscribed to Rails.error, so a reported error is recorded" do
    # Without this the subscriber would only ever be exercised by a test that calls
    # `Rails.error` itself, and the real producers — an unhandled exception, a failed
    # job — would be untested wiring.
    assert_includes Rails.error.instance_variable_get(:@subscribers).map(&:class), ErrorTracking::Subscriber

    log = capture_log do
      Rails.error.report(ArgumentError.new("reported through the seam"), handled: false, source: "test")
    end

    assert_includes log, "reported through the seam"
  end
end
