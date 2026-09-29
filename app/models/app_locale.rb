# The language preference a browser carries for this application.
#
# It is deliberately not a `User` attribute and not a universe setting, for the
# same reason the theme is not (see ADR 0013): a reader's language belongs to
# the person using the browser, it has to work for a guest before a universe is
# chosen and on the landing page, and no universe admin may impose one on a
# collaborator. It is therefore read from and written to a signed cookie, and
# `ApplicationController` sets `I18n.locale` from it for the request.
#
# The labels are the language's own name written in that language ("English",
# "Español"), not a translation of it. A reader who cannot read the current
# language still has to be able to find their own, so a label is a fixed
# property of a locale rather than a translatable string.
#
# Every value that reaches the document goes through `normalize`, so a forged or
# stale cookie can only ever select one of the known locales — which also means
# it can never put an arbitrary string into `I18n.locale` or into `<html lang>`.
class AppLocale
  LOCALES = {
    "en" => { label: "English", html_lang: "en" },
    "es" => { label: "Español", html_lang: "es" }
  }.freeze

  DEFAULT = "en"
  COOKIE_NAME = :um_locale
  # A language is a far more stable preference than a theme, but it is still
  # replaceable, and a reader who has just learned a second language should not
  # be stuck with the first one.
  EXPIRES_IN = 1.year

  class << self
    def names
      LOCALES.keys
    end

    def default
      DEFAULT
    end

    def known?(locale)
      LOCALES.key?(locale.to_s)
    end

    def label_for(locale)
      LOCALES.fetch(normalize(locale))[:label]
    end

    # The value for `<html lang>`. It is the locale's own BCP 47 subtag, which
    # for these two locales is identical to the stored name; the indirection is
    # what keeps the document attribute and the stored preference from drifting
    # into two separate sources of truth.
    def html_lang_for(locale)
      LOCALES.fetch(normalize(locale))[:html_lang]
    end

    # The `I18n.locale` symbol for this preference.
    def to_sym(locale)
      normalize(locale).to_sym
    end

    # The locale this request should render in. Anything unknown — a missing
    # cookie, a cookie signed by an older key, a hand-edited value, a locale this
    # deployment no longer ships — is the default rather than an error, because
    # a language must never block a page.
    def read(cookies)
      normalize(cookies.signed[COOKIE_NAME])
    end

    def write(cookies, locale)
      cookies.signed[COOKIE_NAME] = {
        value: normalize(locale),
        expires: EXPIRES_IN.from_now,
        httponly: true,
        same_site: :lax,
        secure: Rails.env.production?
      }
    end

    private
      # The only way a locale name enters the application. An unknown value is
      # the default, never rendered and never written back.
      def normalize(locale)
        candidate = locale.to_s
        LOCALES.key?(candidate) ? candidate : DEFAULT
      end
  end
end
