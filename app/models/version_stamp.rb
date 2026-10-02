# The version a record was last seen at, in the form a remembered change stores
# so it can tell whether the record moved underneath it.
#
# The stamp is a string because it is written into a row and read back days
# later, and the comparison must not depend on how the database happened to store
# a timestamp. Both sides are normalized through `capture` before they are
# compared, which is the whole point of this class: a `Time` compared against the
# string it was serialized from is never equal to it, so a naive comparison would
# report a conflict on *every* change and make the conflict resolution UI useless.
#
# `updated_at` is the version rather than an integer revision column, and that is
# a decision with consequences rather than a default. See ADR 0019.

# Sub-second digits, fixed. Rails stores datetimes with microsecond precision, so
# two writes inside one second are still distinguishable — without that, a second
# edit is a silently missed conflict rather than a visible one. Both sides pad or
# truncate identically because both are produced by `VersionStamp.capture`.
VERSION_STAMP_PRECISION = 6

VersionStamp = Data.define(:stamp) do
  class << self
    # The current version of a record. This is the only constructor to use; it
    # normalizes, so a stamp built by hand from a raw value cannot disagree with
    # one that was remembered.
    def capture(record)
      new(record.updated_at&.utc&.iso8601(VERSION_STAMP_PRECISION))
    end

    # Whether a record has moved since `taken` was captured. `taken` is whatever
    # was stored — a string from a row, another stamp, or nil for a change that had
    # no base to begin with — and all three are compared as strings. A nil `taken`
    # compares unequal to a real stamp, which makes an unknown base count as
    # moved: the conservative direction, because a conflict the author can see and
    # answer is recoverable and a silently overwritten edit is not.
    def changed?(record, taken)
      capture(record).stamp != taken.to_s
    end
  end

  # A record that has never been stamped, and therefore has nothing to compare
  # against. Only an unsaved record reaches this.
  def blank?
    stamp.nil?
  end

  def to_s
    stamp.to_s
  end
end
