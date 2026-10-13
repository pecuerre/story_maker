# Platform settings: the preferences that belong to the person using the
# application rather than to a universe or a story.
#
# The page is deliberately *not* part of the universe workspace. Theme, language,
# and start page are per-browser choices, so they have to be reachable with no
# universe selected (the landing page) and by a guest, which is also why it
# skips the universe callbacks and the universe authorization chain entirely.
#
# It follows the plain full-page form pattern: a `PATCH` that either remembers
# the choice and redirects, or refuses it and says so. There is no record to
# save, so no JSON mutation contract applies.
#
# The sections are one page with a query-parameter tab (`?section=language`), not
# separate routes, so the whole page keeps one address. See
# `ApplicationHelper#settings_tabs`.
#
# **One section is not a browser preference.** *Limits* is the platform's own
# configuration — how many universes one account may create — and it is stored in a
# row rather than a cookie, so it is reachable only by an account with
# `users.platform_admin` and is absent from the page for everyone else, including a
# guest. It is the only section whose owner is not the browser, and it is here
# rather than on a page of its own because an operator configuring the platform is
# still a person using the application. ADR 0029 is the decision; `Ability` is the
# authorization.
class SettingsController < ApplicationController
  allow_unauthenticated_access

  skip_before_action :set_current_universe
  skip_before_action :authorize_universe_access

  helper_method :after_settings_url, :limit_param

  # One declared preference per section, so the "is this value known" and
  # "write this preference" pairs cannot drift apart between sections. The key
  # is the request parameter and the reader is the model that owns the cookie.
  #
  # *Limits* is deliberately absent: it stores a row rather than a cookie, so it
  # is validated by `PlatformSetting` and written by `save_limit`, not by a reader
  # with `known?` and `label_for`. Mixing it in here would mean the map claimed a
  # shape the record does not have.
  PREFERENCES = {
    theme: AppTheme,
    locale: AppLocale,
    start_page: AppStartPage
  }.freeze

  # The one platform-owned value on this page. Named rather than written inline
  # because it appears in three places — the parameter, the assignment, and the
  # blank-means-"no limit" rule — and those three must not drift apart.
  LIMIT_PARAM = :universe_creation_limit

  # The form field's name, exposed because the panel builds the input and the name
  # has to be the parameter the controller reads. One declaration, so the input and
  # the assignment cannot drift apart.
  def limit_param
    LIMIT_PARAM
  end

  def show
    store_return_path
  end

  # Every preference on the page is saved by the one `PATCH`, but each is
  # independent: a hand-built request may carry one, another, or several. All
  # are validated before any is written, so a request that refuses one
  # preference does not silently apply the others.
  #
  # That all-or-nothing rule now spans the limit too: a request that carries a
  # refused theme *and* a valid limit stores neither. The two halves are different
  # kinds of write, but refusing half of what an operator asked for and reporting
  # success for the rest is the one answer that cannot be acted on.
  def update
    requested = PREFERENCES.keys.index_with { |preference| params[preference] }
    limit_requested = params.key?(LIMIT_PARAM)
    return head :bad_request if requested.values.all?(&:blank?) && !limit_requested

    refused = requested.select { |preference, value| value.present? && !PREFERENCES[preference].known?(value) }
    limit = limit_requested ? requested_limit : nil

    if refused.any? || limit&.invalid?
      # A refused request stores nothing at all, so the stored preferences are
      # exactly what they were before it arrived.
      return redirect_to settings_redirect_path,
        alert: [ refusal_message(refused), limit&.errors&.full_messages&.to_sentence ].compact_blank.to_sentence,
        status: :see_other
    end

    messages = requested.filter_map do |preference, value|
      next if value.blank?

      save_preference(preference, value)
    end
    messages << save_limit(limit) if limit_requested

    redirect_to settings_redirect_path, notice: messages.to_sentence, status: :see_other
  end

  private
    # The row a limit request would write, already validated but **not** saved, so
    # the refusal path can read its errors without anything having been stored.
    #
    # Blank is an answer here, exactly as it is on the universe form: the number
    # field submits `""` when an operator clears it, and `NULL` is the stored form of
    # "no limit at all". An **omitted** parameter is not an answer, which is why
    # this is only reached when `update` has already asked `params.key?`.
    def requested_limit
      authorize! :manage, PlatformSetting

      value = params[LIMIT_PARAM].to_s.strip
      PlatformSetting.current.tap do |setting|
        setting.universe_creation_limit = value.presence
      end
    end

    def save_limit(setting)
      setting.save!

      t("settings.flash.limit_saved", limit: limit_for_message(setting))
    end

    # What an operator is told they now have. A cleared field reads "no limit" rather
    # than the number the reader would substitute, because a reader would print the
    # default for a row storing `NULL` and that is not what was just chosen.
    def limit_for_message(setting)
      setting.universe_creations_unlimited? ? t("settings.limits.unlimited_value") : setting.universe_creation_limit
    end

    def save_preference(preference, value)
      case preference
      when :locale
        # The confirmation for a language change is written in the language that
        # was just chosen, not the one being left. The reader has already said
        # which language they want; answering them in the old one is the one case
        # where the old language is guaranteed to be wrong. The message is
        # therefore built under the new locale, while the surrounding page is
        # still rendered in the old one — the flash is stored as text and
        # rendered by the next request, which is already in the new language.
        #
        # The interpolation is named `language`, not `locale`: `locale` is a
        # reserved I18n option, so `t(key, locale: "Español")` asks I18n to
        # translate *in* a locale called Español and raises
        # `I18n::InvalidLocale` rather than interpolating anything.
        AppLocale.write(cookies, value)
        I18n.with_locale(AppLocale.to_sym(value)) do
          t("settings.flash.locale_saved", language: AppLocale.label_for(value))
        end
      when :theme
        AppTheme.write(cookies, value)
        t("settings.flash.theme_saved", theme: AppTheme.label_for(value))
      when :start_page
        save_start_page(value)
      end
    end

    # Choosing "the universes list" also forgets where this account was, so the
    # stored destination cannot contradict the choice that was just made. The
    # other answer leaves it alone: remembering is what the reader wants, and
    # the destination is already correct.
    def save_start_page(value)
      AppStartPage.write(cookies, value)
      RememberedDestination.clear(cookies) if value == "universes"

      t("settings.flash.start_page_saved", start_page: AppStartPage.label_for(value))
    end

    # Where a save returns the reader: the section they saved from. The
    # helper's tab strip and this redirect read the same section answer, so the
    # navigation and the destination cannot disagree.
    def settings_redirect_path
      helpers.settings_path_for(section)
    end

    def section
      helpers.current_settings_section
    end

    def refusal_message(refused)
      refused.map do |preference, _value|
        t("settings.flash.#{preference}_unknown")
      end.to_sentence
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
