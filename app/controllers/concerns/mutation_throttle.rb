# The one place a mutation is counted, and the one place a request over the
# budget is refused.
#
# **This is not `ActionController::RateLimiting`.** That macro takes `to:` and
# `within:` as literals captured when the class body is evaluated
# (`actionpack/lib/action_controller/metal/rate_limiting.rb`), so it can only
# express a limit chosen in source. A limit that belongs to a universe and is set
# by that universe's admins is read from a column per request, which means the
# count and the comparison are written out here rather than declared. The macro's
# contract is otherwise exactly what is wanted — a cache counter under a
# namespaced key, refused past `to:` — and the two existing limits in
# `SessionsController` and `PasswordsController` keep using it, because theirs
# are not per-universe and never will be.
#
# ## Where it runs
#
# `ApplicationController` registers it after `authorize_universe_access` and
# before `set_current_story`, which is the only position where all three of its
# inputs exist and the request is already known to be permitted:
#
# - after `resume_session`, so `Current.user` is the account being counted;
# - after `set_current_universe`, so the budget is the universe's and the key is
#   scoped to it;
# - **after** `authorize_universe_access`, deliberately. Counting before the
#   authorization answer would let anyone at all — an anonymous visitor, or a
#   signed-in stranger to a private universe — spend an authorized account's
#   budget with requests that were refused anyway. A limit is a brake on writes
#   that were going to happen; it is not a way to lock somebody out.
#
# Because `Current.universe` is nil off a universe-scoped URL, the platform-level
# mutations (sign-in, password reset, settings, notifications, universe
# creation) are not counted here at all. They are not content mutations of a
# universe, and the sign-in and password-reset paths carry their own limits.
#
# ## What is counted
#
# Only `POST`, `PATCH`, `PUT`, and `DELETE`. A `GET` never writes, and a throttle
# that answered a burst of page loads would refuse a reader for reading.
#
# ## Where the counter lives
#
# `Rails.cache`, the same store the framework macro would have used. That is a
# deliberate constraint rather than an accident: this application has no Redis,
# and Solid Cache (production) implements `increment` properly under a row lock
# (`solid_cache/store/api.rb`), so a multi-process deployment counts into one
# place. In development it is a `:memory_store`, and in test it is a
# `:null_store`, whose `increment` returns `nil` — which is why the counter is
# inert under the request suite unless a test installs a real store. That is
# asserted rather than assumed in `test/controllers/mutation_throttle_test.rb`.
module MutationThrottle
  extend ActiveSupport::Concern

  # The methods that write. A `GET` is absent on purpose; see the module comment.
  MUTATING_METHODS = %w[POST PATCH PUT DELETE].freeze

  # Namespaced away from every other cache key, and namespaced from the
  # framework's own `rate-limit:` prefix so the two counters can never collide
  # even if a universe id and a remote ip were to produce the same tail.
  KEY_PREFIX = "mutation-throttle".freeze

  private
    def enforce_mutation_limit
      return unless mutation_throttle_applies?
      return if Current.universe.mutations_unlimited?

      count = mutation_counter.increment(mutation_cache_key, 1,
        expires_in: Universe::MUTATION_LIMIT_WINDOW)
      # A store that cannot count (`null_store`, or one whose `increment` opted
      # out) answers `nil`. Refusing on that basis would turn an inert cache into
      # a locked-out application, so an uncounted request is allowed through.
      return if count.nil? || count <= Current.universe.mutation_limit

      refuse_mutation_limit(count)
    end

    def mutation_throttle_applies?
      MUTATING_METHODS.include?(request.request_method) &&
        Current.user.present? &&
        Current.universe.present?
    end

    def mutation_counter
      Rails.cache
    end

    def mutation_cache_key
      "#{KEY_PREFIX}:#{Current.universe.id}:#{Current.user.id}"
    end

    # The two documented response contracts answer a refusal differently, and
    # this is the same split `refuse_request` already makes: a JSON-only
    # controller's caller is the modal, which reads a status code and needs the
    # bare one, while the HTML flow is a browser following a form post and needs
    # somewhere to land with an explanation.
    def refuse_mutation_limit(_count)
      if request.format.json?
        head :too_many_requests
      else
        redirect_back fallback_location: universe_url(Current.universe),
          alert: t("errors.mutation_throttled"), status: :see_other
      end
    end
end
