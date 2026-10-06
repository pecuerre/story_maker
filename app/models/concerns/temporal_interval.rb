# A start and an end that must be in that order.
#
# Three models record an interval: `Event`'s `start_datetime`/`end_datetime`, and
# `Relation`'s and `Ownership`'s `from_date`/`to_date`. All three are optional, and
# all three used to accept a range whose end precedes its start — a range that
# saves, renders, and is then interpreted inconsistently by a reader, the Timeline,
# and `shared.in_world_range`, which prints "From {later} until {earlier}".
#
# **An absent end is not this rule.** A nil end is an interval that is still open,
# or one whose end is not known yet, and both are legitimate: an Event identified
# only by a title, a Relation that has not ended, an Ownership being handed over.
# Only a range with *both* ends present is checked, and only when the end precedes
# the start. Deciding what an open interval means is left to the models that own
# their dates; this concern answers only the one question all three share.
#
# The message is raised against the **end** attribute, because that is the field
# whose value cannot be right, so the error lands on the control the author has to
# change. It is a `shared.errors` key rather than one per model: all three say the
# same thing about a different noun, and the attribute the message is attached to
# already supplies that noun through `errors.format` ("%{attribute} %{message}").
module TemporalInterval
  extend ActiveSupport::Concern

  class_methods do
    # Declares the two columns an interval is read from, e.g.
    # `has_temporal_interval from: :start_datetime, to: :end_datetime`.
    def has_temporal_interval(from:, to:)
      @temporal_interval_from = from
      @temporal_interval_to = to

      validate :interval_does_not_run_backwards
    end

    # The attribute names this model declared, or nil when it declares none.
    # Public so a caller can reason about an interval without reaching into the
    # concern's ivars.
    def temporal_interval_attributes
      return unless defined?(@temporal_interval_from) && @temporal_interval_from

      { from: @temporal_interval_from, to: @temporal_interval_to }
    end
  end

  private
    def interval_does_not_run_backwards
      attributes = self.class.temporal_interval_attributes
      return unless attributes

      starts_at, ends_at = attributes.values.map { |attribute| public_send(attribute) }

      # An open or unknown end is allowed; see the module comment.
      return if starts_at.blank? || ends_at.blank?
      return if ends_at >= starts_at

      errors.add(attributes[:to], I18n.t("shared.errors.interval.must_not_be_reversed"))
    end
end
