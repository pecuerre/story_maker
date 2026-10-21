# The one place a mutation is counted, and the one place a request over a budget
# is refused.
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
# ## What is counted
#
# Only `POST`, `PATCH`, `PUT`, and `DELETE`. A `GET` never writes, and a throttle
# that answered a burst of page loads would refuse a reader for reading.
#
# ## The two budgets a universe-scoped write is checked against
#
# `universes.mutation_limit` is the whole of this universe's write exposure, and
# every mutation spends it. A mutation that also belongs to one of the **groups**
# below spends a second, tighter counter, and is refused when either is over: the
# universe's budget stays the bound on total writes, and the group's number is what
# binds first inside it. That is what makes the groups sub-limits rather than
# separate buckets — ADR 0029 is the decision.
#
# ### The groups
#
# One bucket for every mutation is a blunt instrument: a burst of photo uploads and
# a burst of scene edits spend the same budget, so either can starve the other
# without either being what the budget was for. Each group below is one action that
# deserves its own number, because it costs something the others do not or reaches
# something the others do not.
#
# - **`:photo`** — a mutating request whose payload carries a photo. This is where
#   image processing costs CPU (`PhotoProcessing`), so it is the group a flood
#   actually hurts. The field is rendered on every editor and submits empty when the
#   author changed no picture, so a **non-blank** `photo_data` is what counts;
#   `remove_photo` is deliberately not in this group, because dropping a picture
#   writes no image and costs no processing.
# - **`:membership`** — every write in `MembershipsController`, which is a grant, a
#   level change, or a removal. All three are in it because all three hand out
#   reach: `UniverseAuthorization` asks for `admin` on the whole controller, and a
#   level change is exactly as much a grant as the first row was.
# - **`:discussion`** — a reply in `MessagesController`. The thread it appends to is
#   append-only, and every message writes the notification its conversation
#   receives, so this group exists because a reply is not one row.
#
# ### The one group with no universe
#
# **`:universe_creation`** is `universes#create`, which is a platform-level write:
# `Current.universe` is nil on `POST /u`, because there is no universe yet to
# resolve. It therefore spends no universe budget and its number comes from
# `PlatformSetting` rather than from a column on the universe it is about to create
# — the one budget in this application whose owner is an operator rather than a
# universe's admins.
#
# ### One request, at most one group
#
# The groups are matched in the order below and the first match wins, so a universe
# created *with* a photo spends the creation group and not the photo group. The
# privileged action is matched first deliberately: its ceiling is an order of
# magnitude tighter than the photo one, and an account cannot create universes in a
# flood anyway, so the request cannot use the precedence to escape a limit that
# mattered.
#
# ## Where the counter lives
#
# `Rails.cache`, the same store the framework macro would have used. That is a
# deliberate constraint rather than an accident: this application has no Redis,
# and Solid Cache (production) implements `increment` properly under a row lock
# (`solid_cache/store/api.rb`), so a multi-process deployment counts into one
# place. In development it is a `:memory_store`, and in test it is a **counting**
# `:memory_store` too — a `:null_store`'s `increment` returns `nil`, which would
# make every limit here inert and unobservable in a request test. That is the
# cost of one shared store whose entries outlive a single test, so a test that
# cares about a counter clears it through `test/test_helpers/throttle_test_helper.rb`,
# and the suite asserts the store counts rather than trusting it.
#
# ## The per-token layer
#
# A mutation that arrives through the bearer-token surface spends one more
# counter, keyed on the token itself (`mutation-throttle:token:<token id>`),
# inside the universe's budget. One agent therefore cannot spend its owner's:
# the token's ceiling is checked separately, and a request is refused when
# either is over. A browser request carries no token, so the layer is a no-op
# off the API surface.
module MutationThrottle
  extend ActiveSupport::Concern

  # The methods that write. A `GET` is absent on purpose; see the module comment,
  # and `ReadThrottle` for the read-side half.
  MUTATING_METHODS = %w[POST PATCH PUT DELETE].freeze

  # Namespaced away from every other cache key, and namespaced from the
  # framework's own `rate-limit:` prefix so the two counters can never collide
  # even if a universe id and a remote ip were to produce the same tail.
  KEY_PREFIX = "mutation-throttle".freeze

  # The window each universe-scoped group is counted in, which is the universe's own
  # `MUTATION_LIMIT_WINDOW` rather than a number of its own — a photo burst and a
  # scene-edit burst are both measured per minute, so the two ceilings are read side
  # by side. `:universe_creation` is the exception and names its own window on
  # `PlatformSetting`, because it is not a universe's budget at all.
  GROUP_WINDOWS = {
    photo: Universe::MUTATION_LIMIT_WINDOW,
    membership: Universe::MUTATION_LIMIT_WINDOW,
    discussion: Universe::MUTATION_LIMIT_WINDOW
  }.freeze

  # Which group a controller's writes belong to, by controller name. Read as a map
  # rather than as a chain of `if`s so that a controller with no group is a name
  # that is simply absent, and so the answer for a given controller cannot change
  # with the order the cases were written in.
  GROUP_BY_CONTROLLER = {
    "memberships" => :membership,
    "messages" => :discussion
  }.freeze

  # What a group counter is scoped to when there is no universe to scope it to. A
  # string, so it cannot collide with a universe id in the key.
  PLATFORM_SCOPE = "platform".freeze

  private
    def enforce_mutation_limit
      return unless mutation_throttle_applies?

      group = mutation_group

      # Every spend runs before any refusal can answer, and the first refusal wins:
      # a request over the universe budget never reaches the token's counter, a
      # request over the token's never reaches the group's, and a request inside
      # all of them spends all three. Spending a counter for a request an earlier
      # budget already refused would count a write that never happened.
      return unless spend_universe_budget
      return unless spend_token_budget
      nil unless spend_group_budget(group)
    end

    def mutation_throttle_applies?
      MUTATING_METHODS.include?(request.request_method) &&
        Current.user.present? &&
        (Current.universe.present? || universe_creation?)
    end

    # The group this mutation belongs to, or `nil` for the ordinary ones that only
    # spend the universe's budget. See "The groups" in the module comment for why
    # each one is here and why the order is what it is.
    def mutation_group
      return :universe_creation if universe_creation?
      return GROUP_BY_CONTROLLER[controller_name] if GROUP_BY_CONTROLLER.key?(controller_name)

      :photo if photo_upload?
    end

    # `POST /u` with no universe in the path: the one platform-level write this
    # module counts. `universes#update` and `#destroy` are universe-scoped and go
    # through the ordinary budget like any other write.
    def universe_creation?
      controller_name == "universes" && action_name == "create"
    end

    # A mutating request carrying a photo. The parameter is nested under whichever
    # model key the request carries (`character[photo_data]`, `universe[photo_data]`,
    # …), so the payload is walked rather than one known key read; and the field is
    # rendered on every editor, so only a **present** value counts — an ordinary
    # rename submits an empty one and must not spend the photo group.
    def photo_upload?
      carries_param?(params, PhotoParams::PHOTO_PARAMS.first)
    end

    def spend_universe_budget
      return true if Current.universe.nil?
      return true if Current.universe.mutations_unlimited?

      count = mutation_counter.increment(universe_cache_key, 1,
        expires_in: Universe::MUTATION_LIMIT_WINDOW)
      # A store that cannot count (`null_store`, or one whose `increment` opted
      # out) answers `nil`. Refusing on that basis would turn an inert cache into
      # a locked-out application, so an uncounted request is allowed through.
      return true if count.nil? || count <= Current.universe.mutation_limit

      refuse_mutation_limit
      false
    end

    # The second layer inside the universe's budget: one counter per token, so
    # one agent cannot spend its owner's. Reuses exactly this module's
    # cache-counter contract, with the token in the key instead of the universe
    # and the account. A browser request carries no token, so this is a no-op
    # off the bearer-token surface.
    def spend_token_budget
      return true if Current.api_token.nil?
      return true if Current.api_token.mutations_unlimited?

      count = mutation_counter.increment(token_cache_key, 1,
        expires_in: Universe::MUTATION_LIMIT_WINDOW)
      return true if count.nil? || count <= Current.api_token.mutation_limit

      refuse_mutation_limit
      false
    end

    # `nil` for the mutations that belong to no group, and for a group whose admin
    # stored `NULL` — the group ceiling is the admin's to remove on its own, which is
    # a different answer from the universe budget being open.
    def spend_group_budget(group)
      return true if group.nil?

      limit = group_limit(group)
      return true if limit.nil?

      count = mutation_counter.increment(group_cache_key(group), 1, expires_in: group_window(group))
      return true if count.nil? || count <= limit

      refuse_mutation_limit(group)
      false
    end

    def group_limit(group)
      return platform_creation_limit if group == :universe_creation
      return nil if Current.universe.mutation_group_unlimited?(group)

      Current.universe.mutation_group_limit(group)
    end

    # The one group's number, read the way the universe groups are read: the
    # predicate first, because the reader answers the **default** for a row storing
    # `NULL` and that number is not what an operator chose.
    def platform_creation_limit
      setting = PlatformSetting.current

      setting.universe_creations_unlimited? ? nil : setting.universe_creation_limit
    end

    def group_window(group)
      return PlatformSetting::UNIVERSE_CREATION_WINDOW if group == :universe_creation

      GROUP_WINDOWS.fetch(group)
    end

    def mutation_counter
      Rails.cache
    end

    def universe_cache_key
      "#{KEY_PREFIX}:#{Current.universe.id}:#{Current.user.id}"
    end

    def token_cache_key
      "#{KEY_PREFIX}:token:#{Current.api_token.id}"
    end

    # The universe's own budget keeps its historical key shape: it is the counter
    # ADR 0028 shipped and the one an operator watching a cache would recognise.
    # The group counters are a new shape under the same prefix, distinguished by the
    # `group:` segment, so the two can never be read as one another.
    def group_cache_key(group)
      "#{KEY_PREFIX}:group:#{group}:#{group_scope}:#{Current.user.id}"
    end

    # A universe id, or the platform's own scope for the one group that has no
    # universe. The two cannot collide: a universe id is an integer.
    def group_scope
      Current.universe&.id || PLATFORM_SCOPE
    end

    # Whether a key carries a **present** value anywhere in a request payload,
    # however deeply it is nested. Absent is not the same as empty here: the photo
    # field exists on every editor and submits empty when nothing changed.
    def carries_param?(node, key)
      return false unless node.respond_to?(:each_pair)

      node.each_pair.any? do |name, value|
        (name.to_s == key.to_s && value.present?) || carries_param?(value, key)
      end
    end

    # The two documented response contracts answer a refusal differently, and this
    # is the same split `refuse_request` already makes: a JSON-only controller's
    # caller is the modal, which reads a status code and needs the bare one, while
    # the HTML flow is a browser following a form post and needs somewhere to land
    # with an explanation.
    def refuse_mutation_limit(group = nil)
      if request.format.json?
        head :too_many_requests
      else
        redirect_back fallback_location: mutation_refusal_fallback_path,
          alert: t(mutation_refusal_message_key(group)), status: :see_other
      end
    end

    # One sentence for a universe's budgets, and one for the platform's: the first
    # names a universe, and universe creation has none yet, so it cannot borrow a
    # sentence about one. Nothing about either refusal is the author's fault, which
    # is why both say to wait rather than to fix something.
    def mutation_refusal_message_key(group)
      group == :universe_creation ? "errors.mutation_throttled_platform" : "errors.mutation_throttled"
    end

    # A refusal redirects back where the request came from, so this is only the
    # answer for a request with no referer to go back to. It has to cope with a
    # universe-less write: `universes#create` is refused on `POST /u`, where the
    # universes list is the only place that exists to land on.
    def mutation_refusal_fallback_path
      Current.universe ? universe_url(Current.universe) : root_path
    end
end
