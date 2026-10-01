# One place to read what the application logged.
#
# There were two ways to want this and no shared way to get it: a job test needed
# the logger the job wrote to, and the request-log and error-tracking tests need
# the same thing from a middleware and from `Rails.error`. Each would otherwise
# assign `Rails.logger` itself, and each assignment is a global one that has to be
# undone even when the block raises.
#
# The logger is swapped, not the destination: the block's output goes to a
# `StringIO`, and the original logger object — including whatever the environment
# wrapped around it, such as `ActiveSupport::TaggedLogging` in production — is put
# back in an `ensure`. Tests run in separate processes (`parallelize(workers:)`),
# so one test's swap is not visible to another's.
module LogTestHelper
  def capture_log
    output = StringIO.new
    previous = Rails.logger
    # `::Logger::Formatter` rather than Active Support's own, which prints the bare
    # message: a test that wants to assert *at which level* something was logged — the
    # difference between a handled warning and an unhandled error — can only do that
    # if the severity is in the captured text.
    Rails.logger = ActiveSupport::Logger.new(output, formatter: ::Logger::Formatter.new)
    yield
    output.string
  ensure
    Rails.logger = previous
  end

  # The JSON events in a captured log, optionally of one `event` name.
  #
  # A log line carries whatever the environment's formatter and log tags put in front
  # of the message — in production `[request-id] INFO -- : ` — so the payload starts at
  # the first `{` rather than at the start of the line. That is also true of what a log
  # shipper has to do with these lines.
  def log_events(log, event_name = nil)
    log.each_line.filter_map do |line|
      start = line.index("{")
      next if start.nil?

      event = JSON.parse(line[start..])
      next unless event.is_a?(Hash)
      next if event_name.present? && event["event"] != event_name

      event
    rescue JSON::ParserError
      next
    end
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include LogTestHelper
end
