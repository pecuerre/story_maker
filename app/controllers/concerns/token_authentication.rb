# Resolves `Authorization: Bearer …` into `Current.user` and `Current.api_token`, and
# narrows the universes a request may reach to the ones the token was issued for.
#
# This is the API-surface counterpart of `Authentication`, which resolves a signed
# session cookie instead. A request carries exactly one of them: the API surface never
# accepts a session, and the browser surface never accepts a bearer token.
module TokenAuthentication
  extend ActiveSupport::Concern

  included do
    # Runs before `ApplicationController`'s chain so `Current.user` and
    # `Current.api_token` exist before a universe is resolved and authorized.
    prepend_before_action :require_api_authentication
  end

  private

    def require_api_authentication
      return if authenticate_with_token

      head :unauthorized, "WWW-Authenticate" => 'Bearer realm="universe-maker"'
    end

    def authenticate_with_token
      return unless bearer_token = bearer_token_from_header

      token = ApiToken.authenticate(bearer_token)
      return unless token

      Current.api_token = token
      token
    end

    def bearer_token_from_header
      return unless header = request.headers["Authorization"]
      return unless header.start_with?("Bearer ")

      header.delete_prefix("Bearer ").strip
    end
end
