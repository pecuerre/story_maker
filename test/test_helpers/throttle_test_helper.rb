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
# can be cleared one account's budget without disturbing anything else.
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

  # Count against one account and one universe `count` times, without the cost of
  # `count` HTTP requests. The guard increments before it compares, so a budget of
  # `n` is spent by the `n`th call and refused on the `n + 1`th.
  def exhaust_mutation_budget(universe, user, count:)
    key = mutation_budget_key(universe, user)

    count.times do
      Rails.cache.write(key, Rails.cache.read(key).to_i + 1,
        expires_in: Universe::MUTATION_LIMIT_WINDOW)
    end
  end

  def clear_mutation_budget(universe, user)
    Rails.cache.delete(mutation_budget_key(universe, user))
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include ThrottleTestHelper
end
