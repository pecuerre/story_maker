require "test_helper"

# The platform's own ceiling, and the one reader that decides how many universes an
# account may create. There is no universe to read it from — that is why it exists —
# so these cases are the only place the rule is pinned.
#
# The values it reads are the same two answers `Universe` gives for its own budget,
# and the same trap comes with them: `universe_creation_limit` answers the default
# for a `NULL` row while `universe_creations_unlimited?` says there is no limit. A
# caller that compared the number without asking the predicate would apply 5 to an
# operator who deliberately stored "none".
class PlatformSettingTest < ActiveSupport::TestCase
  test "a row that stores nothing answers the default and is not unlimited" do
    setting = PlatformSetting.new

    assert_equal PlatformSetting::DEFAULT_UNIVERSE_CREATION_LIMIT, setting.universe_creation_limit
    assert_not setting.universe_creations_unlimited?
  end

  test "a configured number is the one that answers" do
    setting = PlatformSetting.create!(universe_creation_limit: 12)

    assert_equal 12, setting.reload.universe_creation_limit
    assert_not setting.universe_creations_unlimited?
  end

  test "null is the stored form of no limit at all" do
    setting = PlatformSetting.create!(universe_creation_limit: nil)

    assert_nil setting.reload[:universe_creation_limit]
    assert setting.universe_creations_unlimited?
    # The reader still answers a number, and that is deliberate rather than a
    # contradiction: the predicate is what a limit check asks first.
    assert_equal PlatformSetting::DEFAULT_UNIVERSE_CREATION_LIMIT, setting.universe_creation_limit
  end

  test "current is the one row" do
    created = PlatformSetting.create!(universe_creation_limit: 3)

    assert_equal created, PlatformSetting.current
    assert_equal created, PlatformSetting.current
  end

  test "current does not create a row by being read" do
    # A `GET` that wrote would make every page load a candidate for inserting a row,
    # and a refusal to insert would turn a missing row into a 500 on the one path
    # that cannot afford one.
    assert_no_difference -> { PlatformSetting.count } do
      3.times { PlatformSetting.current }
    end
  end

  test "the first save after a missing row writes one row rather than none" do
    setting = PlatformSetting.current
    setting.universe_creation_limit = 2
    setting.save!

    assert_equal 1, PlatformSetting.count
    assert_equal 2, PlatformSetting.current.universe_creation_limit
  end

  test "a null limit is valid and a zero one is not" do
    assert PlatformSetting.new(universe_creation_limit: nil).valid?

    setting = PlatformSetting.new(universe_creation_limit: 0)
    assert_not setting.valid?
    assert_includes setting.errors[:universe_creation_limit], "must be greater than 0"
  end

  test "a fractional limit is a field error" do
    setting = PlatformSetting.new(universe_creation_limit: 1.5)

    assert_not setting.valid?
    assert_includes setting.errors[:universe_creation_limit], "must be an integer"
  end

  test "the window is an hour, which is where this action actually happens" do
    assert_equal 1.hour, PlatformSetting::UNIVERSE_CREATION_WINDOW
  end
end
