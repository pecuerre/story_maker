# Platform settings: the preferences that belong to the person using the
# application rather than to a universe or a story.
#
# The page is deliberately *not* part of the universe workspace. Theme is a
# per-browser choice, so it has to be reachable with no universe selected (the
# landing page) and by a guest, which is also why it skips the universe
# callbacks and the universe authorization chain entirely.
#
# It follows the plain full-page form pattern: a `PATCH` that either remembers
# the choice and redirects, or refuses it and says so. There is no record to
# save, so no JSON mutation contract applies.
class SettingsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :set_current_universe
  skip_before_action :authorize_universe_access

  helper_method :after_settings_url

  def show
    store_return_path
  end

  def update
    theme = params.expect(:theme)

    if AppTheme.known?(theme)
      AppTheme.write(cookies, theme)
      redirect_to settings_path, notice: "Theme set to #{AppTheme.label_for(theme).downcase}.", status: :see_other
    else
      # The control only offers the known themes, so this is a hand-built or
      # stale request. It is refused without touching the stored preference.
      redirect_to settings_path, alert: "Choose either the light or the dark theme.", status: :see_other
    end
  end

  private
    # Remember the page the reader came from so the settings page's **Go back**
    # action can return them to where they left off. Only a same-host referer is
    # stored, so an external site cannot choose the destination, and the settings
    # page itself is skipped so a theme save (which redirects back here) does not
    # overwrite the destination with this page. A later visit from a different
    # page overwrites the stored path, so **Go back** always points at where the
    # reader last came from.
    def store_return_path
      referer = request.referer
      return if referer.blank? || !referer.start_with?("#{request.base_url}/")
      return if referer == settings_url

      session[:return_to_after_settings] = referer
    end

    def after_settings_url
      session[:return_to_after_settings] || root_url
    end
end
