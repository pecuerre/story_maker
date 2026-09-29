# Platform settings: the preferences that belong to the person using the
# application rather than to a universe or a story.
#
# The page is deliberately *not* part of the universe workspace. Theme and
# language are per-browser choices, so they have to be reachable with no universe
# selected (the landing page) and by a guest, which is also why it skips the
# universe callbacks and the universe authorization chain entirely.
#
# It follows the plain full-page form pattern: a `PATCH` that either remembers
# the choice and redirects, or refuses it and says so. There is no record to
# save, so no JSON mutation contract applies.
#
# The two sections are one page with a query-parameter tab (`?section=language`),
# not two routes, so the whole page keeps one address. See
# `ApplicationHelper#settings_tabs`.
class SettingsController < ApplicationController
  allow_unauthenticated_access

  skip_before_action :set_current_universe
  skip_before_action :authorize_universe_access

  helper_method :after_settings_url

  def show
    store_return_path
  end

  # Both preferences live on the one page and are saved by the one `PATCH`, but
  # each is independent: a hand-built request may carry one, the other, or both.
  # Both are validated before either is written, so a request that refuses one
  # preference does not silently apply the other.
  def update
    requested_theme = params[:theme]
    requested_locale = params[:locale]

    return head :bad_request if requested_theme.blank? && requested_locale.blank?

    theme_refused = requested_theme.present? && !AppTheme.known?(requested_theme)
    locale_refused = requested_locale.present? && !AppLocale.known?(requested_locale)

    if theme_refused || locale_refused
      # A refused request stores nothing at all, so the stored preferences are
      # exactly what they were before it arrived.
      return redirect_to settings_redirect_path,
        alert: refusal_message(theme_refused, locale_refused), status: :see_other
    end

    messages = []
    if requested_theme.present?
      AppTheme.write(cookies, requested_theme)
      messages << t("settings.flash.theme_saved", theme: AppTheme.label_for(requested_theme))
    end
    if requested_locale.present?
      AppLocale.write(cookies, requested_locale)
      messages << locale_saved_message(requested_locale)
    end

    redirect_to settings_redirect_path, notice: messages.to_sentence, status: :see_other
  end

  private
    # Where a save returns the reader: the section they saved from. Both the
    # helper's tab strip and this redirect read `settings_language_section?`, so
    # the navigation and the destination cannot disagree.
    def language_section?
      helpers.settings_language_section?
    end

    def settings_redirect_path
      language_section? ? settings_path(section: "language") : settings_path
    end

    def refusal_message(theme_refused, locale_refused)
      messages = []
      messages << t("settings.flash.theme_unknown") if theme_refused
      messages << t("settings.flash.locale_unknown") if locale_refused
      messages.to_sentence
    end

    # The confirmation for a language change is written in the language that was
    # just chosen, not the one being left. The reader has already said which
    # language they want; answering them in the old one is the one case where
    # the old language is guaranteed to be wrong. The message is therefore built
    # under the new locale, while the surrounding page is still rendered in the
    # old one — the flash is stored as text and rendered by the next request,
    # which is already in the new language.
    #
    # The interpolation is named `language`, not `locale`: `locale` is a
    # reserved I18n option, so `t(key, locale: "Español")` asks I18n to translate
    # *in* a locale called Español and raises `I18n::InvalidLocale` rather than
    # interpolating anything.
    def locale_saved_message(locale)
      I18n.with_locale(AppLocale.to_sym(locale)) do
        t("settings.flash.locale_saved", language: AppLocale.label_for(locale))
      end
    end

    # Remember the page the reader came from so the settings page's **Go back**
    # action can return them to where they left off. Only a same-host referer is
    # stored, so an external site cannot choose the destination, and the settings
    # page itself is skipped so a save (which redirects back here) does not
    # overwrite the destination with this page. A later visit from a different
    # page overwrites the stored path, so **Go back** always points at where the
    # reader last came from.
    def store_return_path
      referer = request.referer
      return if referer.blank? || !referer.start_with?("#{request.base_url}/")
      return if referer.start_with?(settings_url)

      session[:return_to_after_settings] = referer
    end

    def after_settings_url
      session[:return_to_after_settings] || root_url
    end
end
