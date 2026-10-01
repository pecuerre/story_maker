require "test_helper"

# The structured request event is the machine-readable half of the log, so these
# tests pin the shape of the line, what it deliberately does not carry, and the
# three pieces of framework behaviour it depends on to stay quiet and correlated.
class RequestLogMiddlewareTest < ActionDispatch::IntegrationTest
  # Every field the event is allowed to carry. Anything else in the JSON is a leak,
  # which is what the privacy test asserts, rather than a list of things to look for
  # by eye.
  FIELDS = %w[
    event request_id request_method request_path request_status
    request_format request_controller request_action duration_ms
  ].freeze

  setup do
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  # One capture can hold several requests, so each example asks for the one it made.
  def request_events(log)
    log_events(log, "request")
  end

  test "a completed request is logged as one structured event" do
    log = capture_log do
      get universe_characters_path(universe_slug: @universe.slug)
    end
    event = request_events(log).sole

    assert_response :success
    assert_equal "GET", event["request_method"]
    assert_equal "/u/#{@universe.slug}/characters", event["request_path"]
    assert_equal 200, event["request_status"]
    assert_equal "text/html", event["request_format"]
    assert_equal "characters", event["request_controller"]
    assert_equal "index", event["request_action"]
    assert_kind_of Float, event["duration_ms"]
    assert_operator event["duration_ms"], :>=, 0
    assert_predicate event["request_id"], :present?
  end

  test "the event's request id is the one the client is given" do
    # One correlation key in three places: the `request_id` log tag every line of the
    # request carries, this field, and the `X-Request-Id` response header that
    # `ActionDispatch::RequestId` sets. If they could differ, a reader following the
    # id from the browser into the log would find nothing.
    log = capture_log do
      get universe_characters_path(universe_slug: @universe.slug)
    end

    assert_equal request_events(log).sole["request_id"], response.headers["X-Request-Id"]
  end

  test "the event carries no more than its allowlist" do
    # The privacy rule, asserted rather than described: no client IP, no cookie, no
    # session, no account, and nothing but the filtered path. The payload is
    # assembled from named fields for this reason — a request object carries all of
    # the above and more. (Rails' own `Started ... for 127.0.0.1` line is the
    # framework's, not this event's; `docs/architecture.md` records that the
    # deployment's log retention is what governs it.)
    log = capture_log do
      get universe_characters_path(universe_slug: @universe.slug)
    end
    event = request_events(log).sole

    assert_equal FIELDS.sort, event.keys.sort
    refute_includes log, users(:user_one).email_address
    refute_includes event.values.join(" "), "session_id"
  end

  test "a refused request is logged with the status it was refused with" do
    log = capture_log do
      get universe_character_path(universe_slug: @universe.slug, id: 999_999, format: :json)
    end

    assert_response :not_found
    assert_equal 404, request_events(log).sole["request_status"]
  end

  test "a rejected mutation is logged with the status it was rejected with" do
    log = capture_log do
      post universe_characters_path(universe_slug: @universe.slug),
        params: { character: { name: "" } }, as: :json
    end
    event = request_events(log).sole

    assert_response :unprocessable_content
    assert_equal 422, event["request_status"]
    assert_equal "application/json", event["request_format"]
  end

  test "a password-reset token is redacted from the logged path" do
    # The event uses the request's own `filtered_path`, so the token filter that
    # already protects Rails' `Started ...` line protects this one too. A log line
    # carrying a live reset link would be a way to take over an account.
    token = users(:user_one).password_reset_token

    log = capture_log do
      get edit_password_path(token: token)
    end
    event = request_events(log).sole

    assert_equal "/passwords/[FILTERED]/edit", event["request_path"]
    refute_includes log, token
  end

  test "the health check is silent when the application silences it" do
    # Production sets `config.silence_healthcheck_path`, which Rails implements by
    # raising the log level around the request in `Rails::Rack::SilenceRequest`. The
    # middleware sits inside that, so the probe does not flood the log — pinned here
    # rather than assumed from the placement.
    silent = Rails::Rack::SilenceRequest.new(
      RequestLogMiddleware.new(ok_app),
      path: "/up"
    )

    log = capture_log { assert_equal 200, silent.call(Rack::MockRequest.env_for("/up")).first }

    assert_empty request_events(log)
  end

  test "a request outside the silenced path is still logged" do
    middleware = RequestLogMiddleware.new(ok_app)

    log = capture_log { middleware.call(Rack::MockRequest.env_for("/up")) }

    assert_equal "/up", request_events(log).sole["request_path"]
  end

  test "an exception past the exception handler is logged as a 500 and re-raised" do
    # A non-rescuable exception never produces a status, and the request must still be
    # accounted for. The exception is re-raised rather than swallowed: this middleware
    # records requests, it does not decide what a failure means.
    middleware = RequestLogMiddleware.new(->(_env) { raise ArgumentError, "boom" })

    log = capture_log do
      assert_raises(ArgumentError) { middleware.call(Rack::MockRequest.env_for("/u/one/characters")) }
    end
    event = request_events(log).sole

    assert_equal 500, event["request_status"]
    assert_equal "/u/one/characters", event["request_path"]
  end

  test "an error reported while the request is running finds the request it belongs to" do
    # The execution context is what `Rails.error` subscribers receive. `Current` would
    # answer "who signed in"; this answers "which request", which is the question an
    # error report has.
    contexts = []
    subscriber = ActiveSupport::Notifications.subscribe("process_action.action_controller") do
      contexts << ActiveSupport::ExecutionContext.to_h
    end

    capture_log do
      get universe_characters_path(universe_slug: @universe.slug)
    end
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)

    payload = ErrorTracking.build_payload(ArgumentError.new("inside"), handled: false, severity: :error,
      context: contexts.sole, source: "test")

    assert_equal response.headers["X-Request-Id"], payload[:request][:request_id]
    assert_equal "/u/#{@universe.slug}/characters", payload[:request][:request_path]
    assert_equal "GET", payload[:request][:request_method]
  end

  test "the request's correlation data does not reach the next request" do
    # The executor above this middleware clears the execution context when the request
    # ends. A value that survived would attach one request's path to a later request's
    # error report — the failure mode that would make an error report misleading
    # rather than merely noisy.
    capture_log do
      get universe_characters_path(universe_slug: @universe.slug)
    end

    assert_empty ActiveSupport::ExecutionContext.to_h
  end

  private
    def ok_app
      ->(_env) { [ 200, { "content-type" => "text/html" }, [ "ok" ] ] }
    end
end
