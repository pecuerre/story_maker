# Where a reader lands when they sign in.
#
# It is a platform preference for the same reason the theme and the language are
# (ADR 0013): it belongs to the person using the browser, it has to work before
# a universe is chosen and with no account at all, and no universe admin may
# impose it on a collaborator. It is therefore a signed cookie and not a `User`
# column and not a universe setting.
#
# It is deliberately not part of Appearance or Language. A theme and a language
# change how the page is *drawn*; this changes *which page* is opened, so it
# gets its own section on the settings page.
#
# Every value that reaches the application goes through `normalize`, so a forged
# or stale cookie can only ever select one of the two known answers.
class AppStartPage
  START_PAGES = {
    "remember" => { icon: "bookmark-check" },
    "universes" => { icon: "collection" }
  }.freeze

  # Remembering is the default: a reader who signs in almost always wants the
  # work they left rather than a list they have to choose from again.
  DEFAULT = "remember"
  COOKIE_NAME = :um_start_page
  # A year, like the other replaceable browser values here: long enough not to
  # be re-picked, short enough not to outlive the wording of the choice.
  EXPIRES_IN = 1.year

  class << self
    def names
      START_PAGES.keys
    end

    def default
      DEFAULT
    end

    def known?(name)
      START_PAGES.key?(name.to_s)
    end

    # The labels and descriptions are chrome, so they are translated: what this
    # application calls the choice has to be readable in the reader's own
    # language. The icon is not — it is a Bootstrap icon name.
    def label_for(name)
      I18n.t("start_pages.#{normalize(name)}.label")
    end

    def icon_for(name)
      START_PAGES.fetch(normalize(name))[:icon]
    end

    def description_for(name)
      I18n.t("start_pages.#{normalize(name)}.description")
    end

    # Whether a sign-in should return the reader to where they were. An unknown
    # value answers `true`, matching the default: an unreadable cookie must not
    # quietly change where the application sends someone.
    def remember?(cookies)
      normalize(read_raw(cookies)) == "remember"
    end

    def read(cookies)
      normalize(read_raw(cookies))
    end

    def write(cookies, name)
      cookies.signed[COOKIE_NAME] = {
        value: normalize(name),
        expires: EXPIRES_IN.from_now,
        httponly: true,
        same_site: :lax,
        secure: Rails.env.production?
      }
    end

    private
      def read_raw(cookies)
        cookies.signed[COOKIE_NAME]
      end

      # The only way a start page enters the application. An unknown value is the
      # default, never rendered and never written back.
      def normalize(name)
        candidate = name.to_s
        START_PAGES.key?(candidate) ? candidate : DEFAULT
      end
  end
end
