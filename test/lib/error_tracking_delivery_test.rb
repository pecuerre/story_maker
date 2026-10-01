require "test_helper"

# What leaves the process when a collector is configured.
#
# `ErrorTracking.client_factory` is substituted rather than a local HTTP server being
# started: the DSN contract is https-only, and exempting a loopback address from that
# rule for the sake of a test would weaken the rule itself. So these examples pin what
# this module decides — the destination, the content type, the redacted body, which
# reports are forwarded — while the socket stays `Net::HTTP`'s own contract rather than
# a claim made here.
class ErrorTrackingDeliveryTest < ActiveSupport::TestCase
  # Stands in for the client `deliver` opens. It records what was posted and can be made
  # to fail, which is the failure mode that matters here: a collector that is down must
  # cost a log line and nothing else.
  class StubClient
    attr_reader :uris, :requests, :failure

    def initialize(failure: nil)
      @failure = failure
      @uris = []
      @requests = []
    end

    def start
      yield self
    end

    def request(post)
      raise failure if failure

      requests << post
      nil
    end
  end

  setup do
    ErrorTracking.reset!
    @previous_dsn = ENV[ErrorTracking::DSN_VARIABLE]
    ENV.delete(ErrorTracking::DSN_VARIABLE)
    @client = StubClient.new
  end

  teardown do
    ENV[ErrorTracking::DSN_VARIABLE] = @previous_dsn
    ErrorTracking.reset!
  end

  test "an unhandled error is posted to the configured collector as redacted JSON" do
    with_collector do
      ErrorTracking.record(RuntimeError.new("failed for writer@example.com"),
        handled: false, severity: :error, context: { request_id: "abc" }, source: "test")
    end

    post = @client.requests.sole
    assert_equal "https://collector.example/api/1", @client.uris.sole.to_s
    assert_equal "application/json", post["content-type"]
    assert_equal "/api/1", post.path

    payload = JSON.parse(post.body)
    assert_equal "RuntimeError", payload["error_class"]
    assert_equal "failed for [FILTERED]", payload["message"]
    assert_equal({ "request_id" => "abc" }, payload["request"])
  end

  test "an error the application recovered from is logged but not forwarded" do
    # `handled: true` is the framework's word for an error the application caught and
    # carried on from. Sending those to a third party would turn a stream of expected
    # warnings into someone else's storage and retention problem.
    with_collector do
      ErrorTracking.record(ArgumentError.new("recovered"), handled: true, severity: :warning, source: "test")
    end

    assert_empty @client.requests
  end

  test "a collector that cannot be reached costs one log line and does not raise" do
    @client = StubClient.new(failure: Errno::ECONNREFUSED.new)

    with_collector do
      payload = nil

      log = capture_log do
        # The report is logged and returned before delivery is attempted, so a collector
        # that is down cannot lose it, and a request that happened to fail cannot fail
        # again because reporting it did.
        payload = ErrorTracking.record(ArgumentError.new("boom"), handled: false, severity: :error, source: "test")
      end

      assert_equal "boom", payload[:message]
      assert_includes log, "boom"
      assert_includes log, "could not deliver an error report"
    end
  end

  test "a delivery failure never prints the collector's own address" do
    # The DSN is a credential — the key is in its path — and anything this module logs
    # about a failed delivery can quote it: a transport error that carries the URL, a
    # gateway that echoes the request line. Logging that without redaction would publish
    # the key on every collector outage.
    dsn = "https://collector.example/api/secret-key-1234"
    @client = StubClient.new(failure: SocketError.new("getaddrinfo failed for #{dsn}"))

    with_collector(dsn) do
      log = capture_log do
        ErrorTracking.record(ArgumentError.new("boom"), handled: false, severity: :error, source: "test")
      end

      refute_includes log, "secret-key-1234"
      assert_includes log, "[FILTERED]"
    end
  end

  private
    # Points the DSN at a collector this process never contacts, and hands `deliver` the
    # stub in place of a client.
    def with_collector(dsn = "https://collector.example/api/1")
      ENV[ErrorTracking::DSN_VARIABLE] = dsn
      ErrorTracking.reset!
      ErrorTracking.client_factory = lambda { |uri|
        @client.uris << uri
        @client
      }

      yield
    end
end
