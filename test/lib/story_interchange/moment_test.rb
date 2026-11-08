require "test_helper"

# The one parser for a Scene's parseable when. The validator refuses a value it
# cannot read, and the import turns the same value into an Event datetime or a
# temporal reference, so the shapes are held here rather than only through a
# source tree.
class StoryInterchangeMomentTest < ActiveSupport::TestCase
  test "reads a date and clock time as a UTC point" do
    moment = StoryInterchange::Moment.parse("2050-03-03 09:20")

    assert_predicate moment, :valid?
    assert_equal :datetime, moment.kind
    assert_equal Time.utc(2050, 3, 3, 9, 20), moment.datetime
  end

  test "reads a date alone as midnight" do
    moment = StoryInterchange::Moment.parse("3550-03-03")

    assert_equal :date, moment.kind
    assert_equal Time.utc(3550, 3, 3), moment.datetime
  end

  test "reads a span before or after another scene" do
    moment = StoryInterchange::Moment.parse("1500 years after 02-the-flare/01-the-flare")

    assert_predicate moment, :span?
    assert_equal "after", moment.direction
    assert_equal 1500, moment.amount
    assert_equal :years, moment.unit
    assert_equal "02-the-flare/01-the-flare", moment.reference
    assert_nil moment.datetime
  end

  test "reads a bare direction and a simultaneous relation" do
    before = StoryInterchange::Moment.parse("before 06-the-meeting/02-the-page")
    simultaneous = StoryInterchange::Moment.parse("at the same time as 06-the-meeting/02-the-page")

    assert_equal :direction, before.kind
    assert_equal "before", before.direction
    assert_equal "06-the-meeting/02-the-page", before.reference
    assert_predicate simultaneous, :simultaneous?
    assert_equal "06-the-meeting/02-the-page", simultaneous.reference
  end

  test "reads a blank value as the empty form and a YAML date as a date" do
    assert_predicate StoryInterchange::Moment.parse(""), :empty?
    assert_predicate StoryInterchange::Moment.parse(nil), :empty?
    assert_equal Time.utc(2050, 1, 1), StoryInterchange::Moment.parse(Date.new(2050, 1, 1)).datetime
  end

  test "refuses an impossible date, a bad time, and a prose value" do
    [ "2050-02-30", "2050-03-03 24:00", "the first night" ].each do |raw|
      moment = StoryInterchange::Moment.parse(raw)

      assert_not moment.valid?, "#{raw.inspect} should not parse"
      assert moment.error.present?
    end
  end

  test "refuses a relation that does not name a chapter and scene" do
    moment = StoryInterchange::Moment.parse("after 01-the-gate")

    assert_not moment.valid?
  end
end
