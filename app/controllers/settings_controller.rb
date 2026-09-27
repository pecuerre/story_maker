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

  def show
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
end
