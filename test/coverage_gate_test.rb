require "test_helper"

# The coverage floor is sized for the whole suite, so it must not be applied to a
# run that selected part of it. `test/coverage_helper.rb` registers `CoverageGate`
# as a Minitest plugin and asks it with Minitest's parsed options; these cases pin
# the shape of those options rather than the plugin machinery, so a Rails or
# Minitest option rename shows up here instead of as `CI=1 bin/rails test
# test/models/session_test.rb` failing on coverage it could not have earned.
class CoverageGateTest < ActiveSupport::TestCase
  test "a run with no file arguments or filters is the whole suite" do
    assert CoverageGate.whole_suite?({})
    assert CoverageGate.whole_suite?({ test_files: [] })
  end

  test "a test file, directory, or line argument is a partial run" do
    refute CoverageGate.whole_suite?({ test_files: [ "test/models/session_test.rb" ] })
    refute CoverageGate.whole_suite?({ test_files: [ "test/models" ] })
    refute CoverageGate.whole_suite?({ test_files: [ "test/models/session_test.rb:12" ] })
  end

  test "a name filter is a partial run" do
    refute CoverageGate.whole_suite?({ include: "/session/" })
  end

  test "an exclusion filter is a partial run" do
    refute CoverageGate.whole_suite?({ exclude: "/session/" })
  end

  test "the gate is registered with Minitest" do
    assert_includes Minitest.extensions, CoverageGate
  end
end
