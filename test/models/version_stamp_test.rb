require "test_helper"

# A remembered change stores the version its record was at, and compares that
# against the record when it is applied. The comparison is the whole risk here: a
# Time compared to the string it was serialized from is never equal, so a naive
# comparison would report a conflict on every change.
class VersionStampTest < ActiveSupport::TestCase
  setup do
    @character = characters(:character_one)
  end

  test "a stamp is a normalized string, not a Time" do
    stamp = VersionStamp.capture(@character)

    assert_kind_of String, stamp.stamp
    assert_equal @character.updated_at.utc.iso8601(6), stamp.stamp
    assert_not_equal @character.updated_at.to_s, stamp.stamp
  end

  test "a record that has not moved is not reported as changed" do
    taken = VersionStamp.capture(@character)

    # The stamp survives a round trip through storage as the string it is, which is
    # the shape a draft change keeps it in.
    assert_not VersionStamp.changed?(@character, taken.stamp)
    assert_not VersionStamp.changed?(@character, taken.to_s)
    assert_not VersionStamp.changed?(@character, VersionStamp.new(taken.stamp))
    assert_not VersionStamp.changed?(@character.reload, taken.stamp)
  end

  test "an edit is reported as changed" do
    taken = VersionStamp.capture(@character)

    @character.update!(description: "Edited after the change was drafted")

    assert VersionStamp.changed?(@character, taken.stamp)
  end

  test "a soft delete is a move, and the stamp sees it" do
    taken = VersionStamp.capture(@character)

    @character.soft_delete

    assert VersionStamp.changed?(@character, taken.stamp)
  end

  test "an unknown base counts as changed rather than as safe" do
    # The conservative direction matters more than tidiness here: a base nobody
    # can compare must not look like a base that still holds.
    assert VersionStamp.changed?(@character, nil)
    assert VersionStamp.changed?(@character, "")
    assert VersionStamp.changed?(@character, "not a stamp")
  end

  test "an unsaved record has a blank stamp" do
    assert VersionStamp.capture(Character.new(name: "Unsaved")).blank?
    assert_not VersionStamp.capture(@character).blank?
  end

  test "two writes in the same second are still distinguishable" do
    # The timestamps are written explicitly so the test does not depend on a wall
    # clock. Both writes land inside one second, which is the case a coarser
    # version would collapse and turn into a silently missed conflict.
    base = Time.current.change(usec: 100_000)
    through_seconds = ->(stamp) { stamp[0, 19] }

    @character.update_columns(updated_at: base, description: "First")
    first = VersionStamp.capture(@character)

    @character.update_columns(updated_at: base + 0.5, description: "Second")
    second = VersionStamp.capture(@character)

    assert_equal base.to_time.utc.iso8601(6), first.stamp
    assert_equal through_seconds.call(first.stamp), through_seconds.call(second.stamp)
    assert_not_equal first.stamp, second.stamp
    assert VersionStamp.changed?(@character, first.stamp)
  end

  test "the stamp format is fixed so two stamps of one record are identical" do
    stamp = VersionStamp.capture(@character).stamp

    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z\z/, stamp)
    assert_equal VERSION_STAMP_PRECISION, 6
    assert_equal stamp, VersionStamp.capture(@character.reload).stamp
  end
end
