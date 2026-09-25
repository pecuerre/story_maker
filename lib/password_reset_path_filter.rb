# Password reset tokens are carried in a URL path segment so that the mailer can
# produce a conventional one-click link. Rails filters matching parameters, but
# it does not filter path segments in its request-start log line.
module PasswordResetPathFilter
  TOKEN_PATH = %r{\A(/passwords/)(?!new(?:\z|/))[^/]+}.freeze

  def filtered_path
    super.sub(TOKEN_PATH) { "#{Regexp.last_match(1)}[FILTERED]" }
  end
end

ActiveSupport.on_load(:action_dispatch_request) do
  prepend PasswordResetPathFilter
end
