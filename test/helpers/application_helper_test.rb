require "test_helper"

class ApplicationHelperTest < ActiveSupport::TestCase
  include ApplicationHelper

  setup do
    @controller = Struct.new(:controller_name).new("characters")
  end

  test "visible? reports whether a requested controller is current" do
    assert visible?(:characters)
    assert_not visible?(:locations)
  end

  test "detail_fact states a missing value instead of rendering a blank row" do
    assert_equal "Character", detail_fact("Type", "Character")[:value]
    assert_equal "No description yet.", detail_fact("Description", nil, blank: "No description yet.")[:value]
    assert_equal "No description yet.", detail_fact("Description", "", blank: "No description yet.")[:value]
  end

  test "in_world_range states open and absent bounds explicitly" do
    from = Time.utc(2026, 9, 11, 9)
    to = Time.utc(2026, 9, 11, 10)

    assert_equal "No dates set yet.", in_world_range(nil, nil)
    assert_equal "From 2026-09-11 09:00", in_world_range(from, nil)
    assert_equal "Until 2026-09-11 10:00", in_world_range(nil, to)
    assert_equal "2026-09-11 09:00 – 2026-09-11 10:00", in_world_range(from, to)
  end

  private
    def controller
      @controller
    end
end
