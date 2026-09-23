require "test_helper"

class UniverseTest < ActiveSupport::TestCase
  test "requires a name" do
    universe = Universe.new(owner: users(:user_one))

    assert_not universe.valid?
    assert_includes universe.errors[:name], "can't be blank"
  end
end
