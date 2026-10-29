# The one irreversible universe operation, on a page of its own.
#
# `UniversesController#destroy` is the application's ordinary delete: it soft
# deletes the universe and its content, which hides it from every page but leaves
# the rows for a restore. This controller is the other one. It asks for `:purge`
# on the universe through `UniverseAuthorization` — answered by Ability's
# `:owner` level, not `:admin`, because an administrator may hide a universe but
# only its creator may erase the work.
#
# The confirmation is the universe's exact name, compared here on the server.
# The input's `autocomplete="off"` and the Stimulus controller beside it only make
# the browser stop helping and stop the button until the words match; neither is
# the rule. A request carrying a different case, a missing comma, an extra space,
# or nothing at all writes nothing and re-renders the page with the reason.
class UniversePurgesController < ApplicationController
  before_action :set_universe

  def show
  end

  def destroy
    unless confirmation_matches?
      flash.now[:alert] = t("universes.purge.form.mismatch", name: @universe.name)
      render :show, status: :unprocessable_content
      return
    end

    @universe.purge!
    forget_this_universe
    redirect_to universes_path, notice: t("universes.purge.flash.destroyed", name: @universe.name),
      status: :see_other
  end

  private
    # A second lookup would be a second object for the universe the request
    # already resolved and authorized — see `UniversesController#set_universe`.
    def set_universe
      @universe = Current.universe
    end

    def confirmation_matches?
      params[:confirmation].to_s == @universe.name
    end

    # The browser keeps a few pointers into a universe that no longer exists. They
    # all already resolve to nothing on the next read, but clearing the ones this
    # request definitely owns keeps the reader from landing on a dead story or a
    # dead "where you were" on the next visit.
    def forget_this_universe
      story_ids = session[:current_story_ids]
      story_ids.delete(@universe.id.to_s) if story_ids.is_a?(Hash)

      DraftEditingSession.stop!(session: session, universe: @universe)

      destination = RememberedDestination.read(cookies)
      RememberedDestination.clear(cookies) if destination && destination[:universe_slug] == @universe.slug
    end
end
