# One structured event per request, on top of the human-readable lines Rails
# already writes.
#
# The tagged STDOUT log answers "what did the server print"; it does not answer
# "which requests were slow" or "how many of them failed" without reading prose
# and joining it by eye. This middleware emits one JSON object per completed
# request, so the same stream can be read by a log shipper and correlated with
# the rest of the log line by line rather than by guesswork.
#
# It deliberately adds to the framework's logging rather than replacing it:
#
#   - `Rails::Rack::Logger` keeps writing `Started ...`/`Completed ...`, so
#     someone reading `production.log` by hand still reads sentences. Those lines
#     carry the client IP and the raw-ish path; this event carries neither, which
#     is why it is an allowlist of its own rather than a copy of the request.
#   - The line is written *below* `Rails::Rack::Logger`, so the request's log tags
#     are already pushed and this event carries the same `[request_id]` tag as every
#     other line of that request. That tag is the correlation key; this event
#     repeats it as a field so a JSON log store can index it.
#   - It is written *above* `ActionDispatch::ShowExceptions`, so a request that ends
#     in an unhandled exception is logged with its 500 status rather than vanishing,
#     and *below* `ActionDispatch::Executor`, which is what reports that exception to
#     `Rails.error` — so an error report raised anywhere in this request can find the
#     request it belongs to.
#   - It is written *below* `Rails::Rack::SilenceRequest`, so
#     `config.silence_healthcheck_path` silences this line exactly as it silences
#     the framework's, with no second health-check rule to keep in step.
class RequestLogMiddleware
  # The request data an error report may correlate against. It is published through
  # `Rails.error`'s execution context rather than through `Current`: `Current` is the
  # account and the scope, this is the request, and an error reporter has no reason
  # to know who signed in.
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # Published before the request runs, so an exception raised inside an action and
    # an error reported by application code both find the request. The fields that
    # only exist once routing has happened are added on the way out.
    publish(request, status: nil)

    response = @app.call(env)
    log_request(request, response.first, started_at)
    response
  rescue Exception
    # A request that raised past `ShowExceptions` (a non-rescuable exception, or a
    # failure inside the middleware below) never produced a status. It is still
    # logged, still tagged, and it is the exception's own line that carries the class
    # and backtrace — this event's job is the request, not the error.
    log_request(request, 500, started_at)
    raise
  end

  private
    def log_request(request, status, started_at)
      payload = publish(request, status: status).merge(
        event: "request",
        duration_ms: elapsed_ms(started_at)
      ).compact

      Rails.logger.info { payload.to_json }
    end

    # One place builds the event, and the execution context takes the same fields, so
    # the log line and an error report cannot describe a request differently.
    def publish(request, status:)
      {
        request_id: request.request_id,
        request_method: request.request_method,
        request_path: request.filtered_path,
        request_status: status,
        request_format: request_format(request),
        request_controller: route_parameter(request, "controller"),
        request_action: route_parameter(request, "action")
      }.tap { |context| Rails.error.set_context(**context) }
    end

    # The router's path parameters are symbol-keyed, and a request that never
    # reached one has none at all, so both answers are possible and a `nil` here
    # means "this request named no controller" rather than "the key is a String".
    def route_parameter(request, name)
      parameters = request.path_parameters
      parameters[name] || parameters[name.to_sym]
    end

    # The negotiated media type, not `Request#format`: that method answers with a
    # symbol, a MIME string, or the request path depending on how many types the
    # request accepted, and a log field that changes shape with the request is a
    # log field nobody can group by. Negotiating raises on a malformed
    # `Content-Type` or `Accept` header, which is a request the exception handler
    # answers with a 406 — a middleware that records requests must not turn that
    # into a failure of its own, so the header it could not read is named instead.
    def request_format(request)
      request.formats.first&.to_s
    rescue ActionDispatch::Http::MimeNegotiation::InvalidType
      "invalid"
    end

    def elapsed_ms(started_at)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      (elapsed * 1000).round(1)
    end
end
