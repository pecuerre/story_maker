require "test_helper"

class AppThemeTest < ActiveSupport::TestCase
  test "the known themes are exactly light and dark" do
    assert_equal %w[light dark], AppTheme.names
    assert_equal "light", AppTheme.default
  end

  test "only a known name is accepted" do
    assert AppTheme.known?("dark")
    assert AppTheme.known?(:dark)
    assert_not AppTheme.known?("sepia")
    assert_not AppTheme.known?("")
    assert_not AppTheme.known?(nil)
  end

  test "an unknown name reads and describes as the default" do
    cookie_jar = cookie_jar()

    assert_equal "Light", AppTheme.label_for("sepia")
    assert_equal "sun", AppTheme.icon_for("sepia")
    assert_equal "A light page with dark text.", AppTheme.description_for("sepia")
    assert_equal "light", AppTheme.read(cookie_jar)
  end

  test "a written theme is read back and an unknown one is stored as the default" do
    cookie_jar = cookie_jar()

    AppTheme.write(cookie_jar, "dark")
    assert_equal "dark", AppTheme.read(cookie_jar)

    AppTheme.write(cookie_jar, "chartreuse")
    assert_equal "light", AppTheme.read(cookie_jar)
  end

  test "an unsigned cookie is not a theme" do
    cookie_jar = cookie_jar()
    cookie_jar["um_theme"] = "dark"

    assert_equal "light", AppTheme.read(cookie_jar)
  end

  test "every theme has a label, an icon, and a description" do
    AppTheme.names.each do |name|
      assert_predicate AppTheme.label_for(name), :present?
      assert_predicate AppTheme.icon_for(name), :present?
      assert_predicate AppTheme.description_for(name), :present?
    end
  end

  private
    def cookie_jar
      ActionDispatch::TestRequest.create.cookie_jar
    end
end
