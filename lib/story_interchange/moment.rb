require "date"

module StoryInterchange
  # The parseable half of a Scene's in-world time.
  #
  # The source states its time twice: `timeline` is the sentence a reader reads,
  # and `moment` is the same instant in a form a parser can read. Exactly one
  # value is written, most specific first. This class is the one parser for that
  # grammar, shared by the validator (which refuses a malformed value) and the
  # import (which turns a value into an Event datetime or a relation).
  #
  # The six accepted shapes are:
  #
  #   YYYY-MM-DD HH:MM              a known date and clock time
  #   YYYY-MM-DD                    a known date, no clock time
  #   <N> <unit> before|after <scene>  a known span from another scene
  #   before|after <scene>          only the direction is known
  #   at the same time as <scene>   exactly simultaneous with another scene
  #   ""                            nothing concrete and nothing relative
  #
  # `<scene>` is the target's path under a story's `chapters/` directory without
  # `.md` (`06-the-meeting/02-the-page`), which is unique across chapters.
  class Moment
    DATE = /\A(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})\z/
    DATETIME = /\A(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})[ ](?<hour>\d{2}):(?<minute>\d{2})\z/
    SPAN = /\A(?<amount>\d+)[ ](?<unit>years?|months?|weeks?|days?|hours?|minutes?)[ ](?<direction>before|after)[ ](?<reference>\S.*)\z/
    DIRECTION = /\A(?<direction>before|after)[ ](?<reference>\S.*)\z/
    SIMULTANEOUS = /\Aat the same time as[ ](?<reference>\S.*)\z/
    # A scene path under `chapters/` without `.md`. The validator checks that
    # the named scene exists in the same story; this only checks the shape.
    SCENE_PATH = %r{\A[^/\s]+/[^/\s]+\z}
    # The plural unit an ActiveSupport `advance` understands. The source writes a
    # unit singular when the number is one, but both spellings are read.
    ADVANCE_UNITS = {
      "years" => :years,
      "months" => :months,
      "weeks" => :weeks,
      "days" => :days,
      "hours" => :hours,
      "minutes" => :minutes
    }.freeze

    attr_reader :raw, :kind, :datetime, :direction, :amount, :unit, :reference, :error

    def self.parse(value)
      raw = normalize(value)
      return new(raw: raw, kind: :empty) if raw.empty?

      new(raw: raw, **parse_value(raw))
    end

    # A YAML date or time is already parsed by the frontmatter reader; the
    # grammar is written as a string, so both are put back into its spelling.
    def self.normalize(value)
      case value
      when DateTime then value.strftime("%Y-%m-%d %H:%M")
      when Date then value.iso8601
      when Time then value.strftime("%Y-%m-%d %H:%M")
      else value.to_s.strip
      end
    end

    def self.parse_value(raw)
      if (match = DATETIME.match(raw))
        datetime = utc_time(match, hour: match[:hour].to_i, minute: match[:minute].to_i)
        return { kind: :datetime, datetime: datetime } if datetime
        return invalid(raw, "is not a valid date and time")
      end

      if (match = DATE.match(raw))
        datetime = utc_time(match)
        return { kind: :date, datetime: datetime } if datetime
        return invalid(raw, "is not a valid date")
      end

      if (match = SPAN.match(raw))
        return invalid(raw, "is not a valid scene reference") unless match[:reference].match?(SCENE_PATH)

        unit = match[:unit].delete_suffix("s")
        return {
          kind: :span,
          direction: match[:direction],
          amount: match[:amount].to_i,
          unit: ADVANCE_UNITS.fetch("#{unit}s"),
          reference: match[:reference]
        }
      end

      if (match = SIMULTANEOUS.match(raw))
        return invalid(raw, "is not a valid scene reference") unless match[:reference].match?(SCENE_PATH)

        return { kind: :simultaneous, reference: match[:reference] }
      end

      if (match = DIRECTION.match(raw))
        return invalid(raw, "is not a valid scene reference") unless match[:reference].match?(SCENE_PATH)

        return { kind: :direction, direction: match[:direction], reference: match[:reference] }
      end

      invalid(raw, "must be `YYYY-MM-DD HH:MM`, `YYYY-MM-DD`, a `before`/`after` scene relation, `at the same time as <scene>`, or empty")
    end

    def self.utc_time(match, hour: 0, minute: 0)
      year = match[:year].to_i
      month = match[:month].to_i
      day = match[:day].to_i
      return unless Date.valid_date?(year, month, day)
      return unless hour.between?(0, 23) && minute.between?(0, 59)

      Time.utc(year, month, day, hour, minute)
    end

    def self.invalid(raw, error)
      { kind: :invalid, error: "#{raw.inspect} #{error}" }
    end

    def initialize(raw:, kind:, datetime: nil, direction: nil, amount: nil, unit: nil, reference: nil, error: nil)
      @raw = raw
      @kind = kind
      @datetime = datetime
      @direction = direction
      @amount = amount
      @unit = unit
      @reference = reference
      @error = error
    end

    def valid?
      kind != :invalid
    end

    def empty?
      kind == :empty
    end

    def relation?
      %i[span direction simultaneous].include?(kind)
    end

    def span?
      kind == :span
    end

    def simultaneous?
      kind == :simultaneous
    end
  end
end
