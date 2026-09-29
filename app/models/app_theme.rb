# The appearance preference a browser carries for this application.
#
# It is deliberately not a `User` attribute and not a universe setting: a theme is
# a per-browser display choice, it must work for a guest on a public universe and
# on the landing page, and no universe admin may impose one on a collaborator. It
# is therefore read from and written to a signed cookie, and the server renders
# the value into `<html data-bs-theme>` so the first paint is already correct and
# the page never flashes the other theme.
#
# Every value that reaches the document goes through `normalize`, so a forged or
# stale cookie can only ever select one of the known themes. That is what keeps
# the value out of attribute-injection territory.
class AppTheme
  THEMES = {
    "light" => { icon: "sun" },
    "dark" => { icon: "moon-stars" }
  }.freeze

  DEFAULT = "light"
  COOKIE_NAME = :um_theme
  # A display preference is a long-lived but replaceable value: a year is long
  # enough that nobody re-picks it daily and short enough that a forgotten
  # preference cannot outlive the design that introduced it.
  EXPIRES_IN = 1.year

  class << self
    def names
      THEMES.keys
    end

    def default
      DEFAULT
    end

    def known?(name)
      THEMES.key?(name.to_s)
    end

    # The label and the description are chrome, so they are translated rather
    # than stored: what the settings page calls a theme has to be readable in
    # the reader's own language. The icon is not translated — it is a Bootstrap
    # icon name, which has nothing to do with the reader's language.
    def label_for(name)
      I18n.t("themes.#{normalize(name)}.label")
    end

    def icon_for(name)
      THEMES.fetch(normalize(name))[:icon]
    end

    def description_for(name)
      I18n.t("themes.#{normalize(name)}.description")
    end

    # The theme this request should render with. Anything unknown — a missing
    # cookie, a cookie signed by an older key, a hand-edited value — is the
    # default rather than an error, because appearance never blocks a page.
    def read(cookies)
      normalize(cookies.signed[COOKIE_NAME])
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
      # The only way a theme name enters the application. An unknown value is the
      # default, never rendered and never written back.
      def normalize(name)
        candidate = name.to_s
        THEMES.key?(candidate) ? candidate : DEFAULT
      end
  end
end
