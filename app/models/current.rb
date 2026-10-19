class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :universe
  attribute :story
  attribute :api_token

  # The account behind the request: a signed-in session, or the bearer token's
  # user on the API surface. Never both at once.
  def user
    session&.user || api_token&.user
  end
end
