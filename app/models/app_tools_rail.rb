# Whether this browser shows the tools rail expanded or as a narrow icon strip.
#
# It is a display preference of the same kind as the theme and the language
# (ADR 0013): it belongs to the person using the browser, it has to work for a
# guest on a public universe, and it is not a universe setting. Reading happens
# here so the first paint is already in the chosen state; writing happens in the
# browser, because the control lives in the rail rather than on the settings
# page.
#
# **The cookie is deliberately not signed**, unlike the theme and the language.
# Its only two outcomes are "collapsed" and "expanded", `read` normalizes
# anything else to the default, and a forged value can therefore change nothing
# but the width of one navigation column. It must never be used for anything
# else: a preference that needs a trusted value belongs in a signed cookie with
# the rest of them.
class AppToolsRail
  COLLAPSED = "collapsed"
  EXPANDED = "expanded"
  COOKIE_NAME = "um_tools_rail"

  class << self
    # The state this request renders. An absent or unrecognized value is the
    # expanded default, which is what every page showed before this preference
    # existed.
    def read(cookies)
      cookies[COOKIE_NAME] == COLLAPSED ? COLLAPSED : EXPANDED
    end

    def collapsed?(cookies)
      read(cookies) == COLLAPSED
    end

    def expanded?(cookies)
      !collapsed?(cookies)
    end
  end
end
