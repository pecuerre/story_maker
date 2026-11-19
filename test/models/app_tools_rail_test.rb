require "test_helper"

class AppToolsRailTest < ActiveSupport::TestCase
  test "an absent cookie renders the rail expanded" do
    assert_equal "expanded", AppToolsRail.read({})
    assert_not AppToolsRail.collapsed?({})
    assert AppToolsRail.expanded?({})
  end

  test "the collapsed value is recognized" do
    cookies = { AppToolsRail::COOKIE_NAME => "collapsed" }

    assert_equal "collapsed", AppToolsRail.read(cookies)
    assert AppToolsRail.collapsed?(cookies)
    assert_not AppToolsRail.expanded?(cookies)
  end

  test "an unknown or forged value falls back to expanded" do
    [ "expanded", "", "bogus", nil, "COLLAPSED" ].each do |value|
      cookies = { AppToolsRail::COOKIE_NAME => value }

      assert_equal "expanded", AppToolsRail.read(cookies), "value #{value.inspect}"
      assert_not AppToolsRail.collapsed?(cookies)
    end
  end
end
