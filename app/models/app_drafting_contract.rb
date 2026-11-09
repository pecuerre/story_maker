# Whether this browser shows a Scene's drafting contract.
#
# It is a display preference of exactly the same kind as the theme and the
# language (ADR 0013): it belongs to the person using the browser, it has to
# work for a guest on a public universe, and no universe admin may impose it on
# a collaborator. It is therefore a signed cookie and not a `User` column and
# not a universe setting.
#
# **Hiding is a display choice, never a data choice.** A story interchange
# import always writes the `DRAFTING CONTRACT` note it finds into the Scene's
# `drafting_contract` column, and the bearer-token Scene API still returns it.
# The preference only decides whether Scene Details and the Scene editor render
# the note for this browser, so turning it off loses nothing an import wrote.
#
# Every value that reaches the application goes through `normalize`, so a forged
# or stale cookie can only ever select one of the two known answers.
class AppDraftingContract
  VISIBILITIES = {
    "show" => { icon: "eye" },
    "hide" => { icon: "eye-slash" }
  }.freeze

  # Showing is the default: the note has always been part of Scene Details, so a
  # reader who has never opened the section already sees what the application
  # showed before this preference existed.
  DEFAULT = "show"
  COOKIE_NAME = :um_drafting_contract
  # A display preference is a long-lived but replaceable value, like the theme.
  EXPIRES_IN = 1.year

  class << self
    def names
      VISIBILITIES.keys
    end

    def default
      DEFAULT
    end

    def known?(name)
      VISIBILITIES.key?(name.to_s)
    end

    # The label and description are chrome, so they are translated rather than
    # stored: what the settings page calls the choice has to be readable in the
    # reader's own language. The icon is not translated — it is a Bootstrap icon
    # name, which has nothing to do with the reader's language.
    def label_for(name)
      I18n.t("drafting_contracts.#{normalize(name)}.label")
    end

    def icon_for(name)
      VISIBILITIES.fetch(normalize(name))[:icon]
    end

    def description_for(name)
      I18n.t("drafting_contracts.#{normalize(name)}.description")
    end

    # Whether a Scene surface should render the note. An unknown value answers
    # `true`, matching the default: an unreadable cookie must not quietly hide
    # content the reader used to see.
    def visible?(cookies)
      normalize(read_raw(cookies)) == "show"
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

      # The only way a visibility enters the application. An unknown value is the
      # default, never rendered and never written back.
      def normalize(name)
        candidate = name.to_s
        VISIBILITIES.key?(candidate) ? candidate : DEFAULT
      end
  end
end
