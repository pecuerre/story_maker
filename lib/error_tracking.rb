# Optional error reporting, off unless an environment variable says otherwise.
#
# `Rails.error` is the framework's one reporting seam, and this application was
# not subscribed to it: an unhandled exception reached `ActionDispatch::Executor`,
# which reports it there with `handled: false`, and then nothing in the process
# recorded the class, the message, or the backtrace. In development the
# `DebugExceptions` page shows them and `log/development.log` holds the rendered
# page; in production neither happens, so a 500 was a status code with no cause
# next to it. This module is that missing record, in two forms:
#
#   1. **A structured `error` event in the log**, always on, in every environment.
#      It is what makes a production 500 diagnosable from the log alone, and it is
#      why no tracker is required to see what failed.
#   2. **A forwarded report to an external collector**, only when
#      `ERROR_TRACKING_DSN` is supplied. Nothing is initialized without it: no
#      client, no socket, no outbound request, and no dependency. It was written
#      against `Net::HTTP` from the standard library precisely so that enabling
#      error tracking does not add a gem to a locked bundle.
#
# The privacy and volume rules are deliberate, not incidental:
#
#   - **Allowlist, not filter.** The payload is assembled from named fields. A
#     request, its headers, its cookies, its session, and its parameters are never
#     passed in, so they cannot ride along; the only request data included is the
#     correlation set `RequestLogMiddleware` publishes through
#     `Rails.error.set_context` (see `CONTEXT_KEYS`).
#   - **Redaction on the way out.** Every string is filtered with the application's
#     own `filter_parameters` and then scrubbed of e-mail addresses and URI
#     credentials, so a message that happens to quote one of them (`SMTP` rejects a
#     recipient by address, for instance) does not publish it. The DSN is scrubbed
#     too, because a delivery failure's message carries the URL it failed to reach.
#   - **Unhandled errors only are forwarded.** `handled: true` is the framework's
#     word for an error the application caught and recovered from; sending those to
#     a third party would turn a stream of expected warnings into someone else's
#     storage and retention problem. They are still logged.
#   - **Bounded and cheap.** At most ten backtrace frames, a capped message, one
#     attempt, two-second connect and read timeouts, no retry queue. Reporting must
#     not be able to slow a request down or queue work of its own.
module ErrorTracking
  # Named rather than configured: a second collector would be a second place to
  # audit what leaves the process.
  DSN_VARIABLE = "ERROR_TRACKING_DSN"

  BACKTRACE_FRAMES = 10
  MESSAGE_LIMIT = 500
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 2

  # The only request data an error report may carry, read from the execution
  # context `RequestLogMiddleware` sets. Everything else in that context belongs
  # to some other feature's decision.
  CONTEXT_KEYS = %i[
    request_id request_method request_path request_status
    request_format request_controller request_action
  ].freeze

  # Collects what `Rails.error` hands a subscriber. It cannot raise: the framework
  # logs a raising subscriber at `fatal` with its own backtrace, which would bury
  # the error being reported under the error reporting it.
  class Subscriber
    def report(error, handled:, severity: :error, context: {}, source: nil)
      ErrorTracking.record(error, handled: handled, severity: severity, context: context, source: source)
    end
  end

  class << self
    # The client `deliver` opens and posts through. `Net::HTTP` is named here and
    # nowhere else, deliberately: enabling error tracking must not add a gem to a locked
    # bundle, so the standard library's client is the implementation and this is the one
    # seam a test substitutes.
    attr_writer :client_factory

    def client_factory
      @client_factory || method(:build_client)
    end

    # Called from `config/initializers/error_tracking.rb`, so a malformed DSN is a
    # boot failure rather than a failure on every request that happens to raise.
    def subscribe!
      dsn
      Rails.error.subscribe(Subscriber.new)
    end

    # The configured collector, or nil when error tracking is off. The value is a
    # credential — it usually carries a key — so it is never logged, never
    # included in a payload, and scrubbed out of any text this module emits.
    def dsn
      return @dsn if defined?(@dsn)

      @dsn = ENV[DSN_VARIABLE].presence&.then { |value| parse_dsn(value) }
    end

    def enabled?
      dsn.present?
    end

    # Build the payload, log it, and forward it when a collector is configured.
    def record(error, handled:, severity: :error, context: {}, source: nil)
      payload = build_payload(error, handled: handled, severity: severity, context: context, source: source)
      Rails.logger.public_send(log_level(severity), payload.to_json)
      deliver(payload) if enabled? && !handled

      payload
    end

    def build_payload(error, handled:, severity:, context: {}, source: nil)
      {
        event: "error",
        error_class: error.class.name,
        message: Redactor.scrub(error.message.to_s).truncate(MESSAGE_LIMIT),
        backtrace: Array(error.backtrace).first(BACKTRACE_FRAMES).map { |frame| Redactor.scrub(frame) },
        severity: severity,
        handled: handled,
        source: source,
        occurred_at: Time.current.utc.iso8601,
        request: context.slice(*CONTEXT_KEYS).presence
      }.compact
    end

    # A test seam and a way to reset memoized configuration between examples.
    def reset!
      remove_instance_variable(:@dsn) if defined?(@dsn)
      @client_factory = nil
    end

    private
      def log_level(severity)
        { warning: :warn }.fetch(severity, :error)
      end

      def deliver(payload)
        uri = URI.parse(dsn)
        post = Net::HTTP::Post.new(uri, "content-type" => "application/json")
        post.body = payload.to_json

        client_factory.call(uri).start { |session| session.request(post) }
      rescue StandardError => error
        # The report is already in the log by this point, so a collector that is
        # down or slow costs one line and nothing else.
        Rails.logger.warn("[error tracking] could not deliver an error report: " \
          "#{Redactor.scrub(error.message.to_s.truncate(MESSAGE_LIMIT))}")
        nil
      end

      def build_client(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = READ_TIMEOUT
        http
      end

      # TLS is required rather than defaulted: the payload carries an application's
      # failures, and sending them to a collector in the clear would be a worse
      # default than refusing to start.
      def parse_dsn(value)
        uri = begin
          URI.parse(value)
        rescue URI::InvalidURIError
          raise "#{DSN_VARIABLE} must be an https URL with a host and a path"
        end

        unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.path.present?
          raise "#{DSN_VARIABLE} must be an https URL with a host and a path"
        end

        uri
      end

      def scrub(text)
        Redactor.scrub(text)
      end
  end

  # The redaction every string this module emits passes through.
  #
  # `config.filter_parameters` is a list of parameter *names*, and the framework
  # applies it to a request's parameters and to the query string by splitting those
  # into `key=value` pairs — which is what this does to an exception message too, so
  # a message quoting `token=…` or `password=…` is redacted the same way the query
  # string would be. The two substitutions after it are the shapes a `key=value` pair
  # does not describe: an address in the middle of a sentence (an SMTP rejection
  # quotes the recipient), and credentials embedded in a URL.
  module Redactor
    FILTERED = "[FILTERED]".freeze
    EMAIL = /[\w.+-]+@[\w-]+(\.[\w-]+)+/
    URI_USERINFO = %r{(?<scheme>[a-z][a-z0-9+.-]*://)[^/\s@]+@}i
    PAIR = %r{(?<key>[A-Za-z_][A-Za-z0-9_.\[\]-]*)=(?<value>[^\s"'&,;)]*)}

    class << self
      def scrub(text)
        return text unless text.is_a?(String)

        # The collector's own address is a credential, and a delivery failure's
        # message contains the address it failed to reach.
        text = text.gsub(ErrorTracking.dsn.to_s, FILTERED) if ErrorTracking.enabled?
        text.gsub(PAIR) { pair_filtered?(Regexp.last_match[:key]) ? "#{Regexp.last_match[:key]}=#{FILTERED}" : Regexp.last_match[0] }
          .gsub(URI_USERINFO) { "#{Regexp.last_match[:scheme]}#{FILTERED}@" }
          .gsub(EMAIL, FILTERED)
      end

      private
        def pair_filtered?(key)
          filtered_keys.any? { |pattern| pattern.match?(key) }
        end

        # The compiled form of the application's own filter list, so the redaction
        # cannot drift from `config.filter_parameters`.
        def filtered_keys
          @filtered_keys ||= ActiveSupport::ParameterFilter
            .precompile_filters(Rails.application.config.filter_parameters)
            .grep(Regexp)
        end
    end
  end
end
