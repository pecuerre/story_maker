require "test_helper"

class AppLocaleTest < ActiveSupport::TestCase
  test "the known locales are exactly English and Spanish" do
    assert_equal %w[en es], AppLocale.names
    assert_equal "en", AppLocale.default
  end

  test "only a known locale is accepted" do
    assert AppLocale.known?("es")
    assert AppLocale.known?(:es)
    assert_not AppLocale.known?("fr")
    assert_not AppLocale.known?("")
    assert_not AppLocale.known?(nil)
  end

  test "a locale is labelled in its own language, not in the current one" do
    # This is the point of the label: a reader who cannot read the current
    # language still has to be able to find their own. It is a fixed property
    # of a locale, so it is stored rather than translated.
    assert_equal "English", AppLocale.label_for("en")
    assert_equal "Español", AppLocale.label_for("es")
  end

  test "an unknown locale reads and describes as the default" do
    cookie_jar = cookie_jar()

    assert_equal "English", AppLocale.label_for("fr")
    assert_equal "en", AppLocale.html_lang_for("fr")
    assert_equal :en, AppLocale.to_sym("fr")
    assert_equal "en", AppLocale.read(cookie_jar)
  end

  test "a written locale is read back and an unknown one is stored as the default" do
    cookie_jar = cookie_jar()

    AppLocale.write(cookie_jar, "es")
    assert_equal "es", AppLocale.read(cookie_jar)

    AppLocale.write(cookie_jar, "fr")
    assert_equal "en", AppLocale.read(cookie_jar)
  end

  test "an unsigned cookie is not a locale" do
    cookie_jar = cookie_jar()
    cookie_jar["um_locale"] = "es"

    assert_equal "en", AppLocale.read(cookie_jar)
  end

  test "every locale has a label and a document language" do
    AppLocale.names.each do |name|
      assert_predicate AppLocale.label_for(name), :present?
      assert_predicate AppLocale.html_lang_for(name), :present?
    end
  end

  test "every locale is one this application actually ships" do
    # A locale the app offered but had no `es.yml`-style file for would render
    # every key missing, so the two lists are asserted to be the same list.
    assert_equal I18n.available_locales.map(&:to_s).sort, AppLocale.names.sort
  end

  private
    def cookie_jar
      ActionDispatch::TestRequest.create.cookie_jar
    end
end
