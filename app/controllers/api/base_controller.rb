# The shared surface for every API controller.
#
# Unlike `ApplicationController`, this is not a browser surface: it never signs a
# session in and never answers HTML. It therefore drops `allow_browser`, the
# session-loading and sign-in callbacks, and forgery protection, while keeping
# `Ability` and `MutationThrottle` (both inherited from `ApplicationController`)
# untouched. A bearer token authenticates the request through `TokenAuthentication`.
class Api::BaseController < ApplicationController
  include TokenAuthentication

  skip_before_action :require_authentication
  skip_before_action :resume_session
  skip_before_action :consume_post_sign_in_destination
  # Story selection is story-scoped; the universe-level resources in this slice do
  # not need it. Story-scoped API controllers re-add it.
  skip_before_action :set_current_story

  skip_forgery_protection

  # `allow_browser versions: :modern` on `ApplicationController` registers a
  # lambda before_action that blocks outdated browsers. There is no browser here,
  # so the guard is dropped for this surface only: its target runs as a no-op.
  def allow_browser(versions:, block:)
  end

  protected

    # Resolves `Current.universe` from `params[:universe_slug]`, but only among the
    # universes this token was issued for. A token for another universe — or none
    # at all — raises `RecordNotFound` and answers `404`, the same way a private
    # universe hides itself from a reader it does not list.
    def set_current_universe
      return unless params[:universe_slug].present?

      Current.universe = Current.api_token.universes.find_by!(slug: params[:universe_slug])
    end
end
