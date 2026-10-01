require "test_helper"

# The start page is the third platform preference: browser-owned, signed, and
# with an unknown value falling back to the default. These cases mirror
# `AppThemeTest` and `AppLocaleTest`, because the point of the shape is that a
# new preference of this kind is the same code again.
class AppStartPageTest < ActiveSupport::TestCase
  test "the known start pages are remembering a story and listing universes" do
    assert_equal [ "remember", "universes" ], AppStartPage.names
    assert_equal "remember", AppStartPage.default
  end

  test "known? answers only for the two declared start pages" do
    assert AppStartPage.known?("remember")
    assert AppStartPage.known?("universes")
    assert_not AppStartPage.known?("everything")
    assert_not AppStartPage.known?("")
    assert_not AppStartPage.known?(nil)
  end

  # A forged or stale cookie must not be able to select anything but one of the
  # two known answers, and must not become an error: an unreadable preference
  # never blocks a page.
  test "an unknown value reads as the default and remembers a story" do
    assert_equal AppStartPage.default, AppStartPage.read(cookies_with("chartreuse"))
    assert AppStartPage.remember?(cookies_with("chartreuse"))

    assert_equal "universes", AppStartPage.read(cookies_with("universes"))
    assert_not AppStartPage.remember?(cookies_with("universes"))
  end

  test "a missing cookie reads as the default" do
    assert_equal AppStartPage.default, AppStartPage.read(cookies_with(nil))
    assert AppStartPage.remember?(cookies_with(nil))
  end

  test "write and read round trip both answers" do
    AppStartPage.names.each do |name|
      jar = ActionDispatch::TestRequest.create.cookie_jar
      AppStartPage.write(jar, name)

      assert_equal name, AppStartPage.read(jar)
      assert_equal name == "remember", AppStartPage.remember?(jar)
    end
  end

  test "write normalizes an unknown value rather than storing it" do
    jar = ActionDispatch::TestRequest.create.cookie_jar
    AppStartPage.write(jar, "everything")

    assert_equal AppStartPage.default, AppStartPage.read(jar)
  end

  # An unsigned cookie is a value anyone can set, so it must not be readable as
  # a preference at all.
  test "an unsigned cookie is not a start page" do
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar[:um_start_page] = "universes"

    assert_equal AppStartPage.default, AppStartPage.read(jar)
    assert AppStartPage.remember?(jar)
  end

  test "every start page has a label, an icon, and a description" do
    AppStartPage.names.each do |name|
      assert_nothing_raised { AppStartPage.label_for(name) }
      assert_nothing_raised { AppStartPage.icon_for(name) }
      assert_nothing_raised { AppStartPage.description_for(name) }
      assert_predicate AppStartPage.label_for(name), :present?
      assert_predicate AppStartPage.icon_for(name), :present?
      assert_predicate AppStartPage.description_for(name), :present?
    end
  end

  private
    def cookies_with(value)
      jar = ActionDispatch::TestRequest.create.cookie_jar
      jar.signed[AppStartPage::COOKIE_NAME] = value if value
      jar
    end
end
