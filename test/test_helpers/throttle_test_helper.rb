# Clearing the counters every limit in the application keeps in the cache.
#
# There are two kinds, and they are cleared differently.
#
# **Framework limits** (`rate_limit` in `SessionsController` and
# `PasswordsController`) resolve their store when the macro is declared, so a
# test cannot install a different one — it can only clear the one the process
# booted with. Their keys are derived inside `ActionController::RateLimiting`
# (`["rate-limit", scope, name, by]`), so rather than reproducing that key shape
# here and guessing wrong the moment Rails changes it, `clear_all_counters`
# empties the store. The suite's store holds nothing else a request test needs.
#
# **The per-universe mutation budget** (`MutationThrottle`) reads `Rails.cache`
# at request time and keys on universe and account, so its counters are named and
# can be cleared one account's budget without disturbing anything else. The same is
# true of each per-group sub-limit (ADR 0029): it is a second counter under the same
# prefix, so `clear_mutation_budget` and `exhaust_mutation_budget` name it rather
# than emptying the store, and a test can spend one budget without touching the
# other.
#
# Both need clearing at all because the test environment's cache is a
# `:memory_store` that counts (`config/environments/test.rb`), which is what
# makes any of these limits observable in a request test — and which also means a
# counter one test spends is still spent in the next one.
module ThrottleTestHelper
  # Empty the cache, so no counter, and no cached menu count, survives into the
  # next test in this process.
  def clear_all_counters
    Rails.cache.clear
  end

  def mutation_budget_key(universe, user)
    "#{MutationThrottle::KEY_PREFIX}:#{universe.id}:#{user.id}"
  end

  # One group's counter. `universe` is `nil` for the one group with no universe —
  # universe creation — which is exactly what the guard resolves the scope to.
  def mutation_group_key(universe, user, group)
    "#{MutationThrottle::KEY_PREFIX}:group:#{group}:#{universe&.id || MutationThrottle::PLATFORM_SCOPE}:#{user.id}"
  end

  # Count against one account and one universe `count` times, without the cost of
  # `count` HTTP requests. The guard increments before it compares, so a budget of
  # `n` is spent by the `n`th call and refused on the `n + 1`th.
  def exhaust_mutation_budget(universe, user, count:)
    write_counter(mutation_budget_key(universe, user), count: count,
      expires_in: Universe::MUTATION_LIMIT_WINDOW)
  end

  # The same, for one per-group sub-limit. The window is the one the guard would use
  # for that group, so a test that expires its own counter is not asking the guard to
  # do something it would not.
  def exhaust_mutation_group(universe, user, group, count:)
    write_counter(mutation_group_key(universe, user, group), count: count,
      expires_in: mutation_group_window(group))
  end

  # What the counter reads now, which is how a test proves that a grouped mutation
  # spends *both* budgets rather than one or the other.
  def mutation_budget_count(universe, user)
    Rails.cache.read(mutation_budget_key(universe, user)).to_i
  end

  def mutation_group_count(universe, user, group)
    Rails.cache.read(mutation_group_key(universe, user, group)).to_i
  end

  def clear_mutation_budget(universe, user)
    Rails.cache.delete(mutation_budget_key(universe, user))
  end

  def clear_mutation_group(universe, user, group)
    Rails.cache.delete(mutation_group_key(universe, user, group))
  end

  # What the guard would use, asked of the same two places it asks: the universe's
  # own window for its groups, and the platform's for universe creation.
  def mutation_group_window(group)
    group == :universe_creation ? PlatformSetting::UNIVERSE_CREATION_WINDOW : Universe::MUTATION_LIMIT_WINDOW
  end

  private
    def write_counter(key, count:, expires_in:)
      count.times do
        Rails.cache.write(key, Rails.cache.read(key).to_i + 1, expires_in: expires_in)
      end
    end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include ThrottleTestHelper
end
