# A reader's own API credentials for one universe: list them, and revoke any
# one of them. The bearer value is shown once at creation and never stored, so
# revoking is the only way to retire a token — a credential its owner cannot
# see or kill is not shippable. A reader sees only their own tokens for this
# universe; anything else is a 404, the same way a private universe hides itself.
class ApiTokensController < ApplicationController
  before_action :set_api_token, only: :destroy

  def index
    @api_tokens = Current.user.api_tokens.for_universe(Current.universe).order(:name)
  end

  def destroy
    @api_token.revoke!
    redirect_to universe_api_tokens_path(universe_slug: Current.universe.slug),
      notice: t("api_tokens.flash.revoked"), status: :see_other
  end

  private

    def set_api_token
      @api_token = Current.user.api_tokens.for_universe(Current.universe)
        .find(params.expect(:id))
    end
end
