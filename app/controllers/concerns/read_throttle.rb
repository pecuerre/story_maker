# Counts every `GET` on the bearer-token surface against a token's own read
# ceiling, and refuses a token that reads faster than it.
#
# `MutationThrottle` counts only `POST`/`PATCH`/`PUT`/`DELETE` — its
# `MUTATING_METHODS` deliberately excludes `GET`, so a reader can never be
# refused by it. This is the read-side half: a read spends one counter under
# its own `read-throttle:` prefix, keyed by token and universe, and a token
# past its ceiling answers `429` like any other refusal.
#
# It runs only where `Current.api_token` exists: the browser surface and its
# guests are never counted, so ordinary page loads and public read-only
# universes are unaffected.
module ReadThrottle
  extend ActiveSupport::Concern

  READ_KEY_PREFIX = "read-throttle".freeze

  private

    def enforce_read_limit
      return if Current.api_token.nil?
      return if Current.api_token.mutations_unlimited?

      count = Rails.cache.increment(read_cache_key, 1,
        expires_in: Universe::MUTATION_LIMIT_WINDOW)
      # A store that cannot count answers `nil`; an uncounted read is allowed
      # through rather than refused by an inert cache.
      return if count.nil? || count <= Current.api_token.mutation_limit

      head :too_many_requests
    end

    def read_throttle_applies?
      request.get? && Current.api_token.present? && Current.universe.present?
    end

    def read_cache_key
      "#{READ_KEY_PREFIX}:token:#{Current.api_token.id}:#{Current.universe.id}"
    end
end
