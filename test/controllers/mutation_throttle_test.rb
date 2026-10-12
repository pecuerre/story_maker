require "test_helper"

# The per-universe mutation budget, and the two contracts it answers a refusal
# with.
#
# The whole file runs against the suite's `:memory_store`, because a limit can
# only be proven against a store that counts. The first test asserts that rather
# than trusting it: without it, a broken guard that never counted anything would
# satisfy every other test here.
class MutationThrottleTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_one)
    @other_universe = universes(:universe_two)

    clear_all_counters
    sign_in_as(@user)
  end

  test "the suite's cache counts, which is what makes every test below mean anything" do
    assert_equal 1, Rails.cache.increment("any-key", 1),
      "a store whose increment returns nil makes the guard allow everything; that is why " \
      "config.cache_store cannot go back to :null_store while any limit is tested this way"

    assert_equal 2, Rails.cache.increment("any-key", 1)
    assert_nil ActiveSupport::Cache::NullStore.new.increment("any-key", 1),
      "the reason for the rule above, kept so the failure mode is named rather than remembered"
  end

  # --- the budget itself -----------------------------------------------------

  test "a mutation under the budget is allowed" do
    exhaust_mutation_budget(@universe, @user, count: 3)

    post universe_characters_path(universe_slug: @universe.slug),
      params: { character: { name: "Written under the budget" } }, as: :json

    assert_response :created
  end

  test "a mutation over the budget is refused with 429 and writes nothing" do
    exhaust_mutation_budget(@universe, @user, count: @universe.mutation_limit)
    assert_no_difference -> { Character.count } do
      post universe_characters_path(universe_slug: @universe.slug),
        params: { character: { name: "Written over the budget" } }, as: :json
    end

    assert_response :too_many_requests
  end

  test "the budget is per account, so one author's spending does not refuse another's" do
    other_user = users(:user_two)
    exhaust_mutation_budget(@universe, @user, count: @universe.mutation_limit)
    exhaust_mutation_budget(@other_universe, other_user, count: @other_universe.mutation_limit)

    post universe_characters_path(universe_slug: @universe.slug),
      params: { character: { name: "By the first author" } }, as: :json
    assert_response :too_many_requests

    sign_in_as(other_user)
    post universe_characters_path(universe_slug: @universe.slug),
      params: { character: { name: "By the second author, who is not over" } }, as: :json
    assert_response :created
  end

  test "the budget is per universe, so spending one does not refuse the next" do
    exhaust_mutation_budget(@universe, @user, count: @universe.mutation_limit)

    post universe_characters_path(universe_slug: @other_universe.slug),
      params: { character: { name: "In the other universe" } }, as: :json

    assert_response :created
  end

  test "an account's budget is not spendable by a signed-in stranger to a private universe" do
    # The ordering this file exists to protect: the counter runs *after*
    # authorization, so a request that would be refused anyway never costs the
    # authorized account anything. `universe_one` is public, so it is made private
    # here — the refusal has to come from the scope, not from the throttle.
    @universe.update!(private: true)
    owner_budget = -> { Rails.cache.read("#{MutationThrottle::KEY_PREFIX}:#{@universe.id}:#{@user.id}") }
    exhaust_mutation_budget(@universe, @user, count: @universe.mutation_limit)

    intruder = users(:user_two)
    sign_in_as(intruder)

    assert_no_difference -> { owner_budget.call } do
      post universe_characters_path(universe_slug: @universe.slug),
        params: { character: { name: "Not allowed here" } }, as: :json
    end

    # A private universe hides itself from a non-member, so the refusal is the
    # 404 and not a 403 that would tell a stranger the universe exists.
    assert_response :not_found
  end

  # --- what is and is not counted -------------------------------------------

  test "a GET is never counted, however many are made" do
    @universe.update!(mutation_limit: 2)
    10.times { get universe_characters_path(universe_slug: @universe.slug) }

    assert_response :success
    assert_nil Rails.cache.read(mutation_budget_key(@universe, @user)),
      "reading a page is not a mutation and must not spend the mutation budget"
  end

  test "a mutation outside any universe is not counted against a universe's budget" do
    exhaust_mutation_budget(@universe, @user, count: @universe.mutation_limit)

    # Platform-level writes are not content mutations of a universe. Signing out
    # is the cheapest one to prove it with.
    delete session_path

    assert_response :see_other
  end

  test "the settings form is a universe-scoped write, so changing the limit spends the budget" do
    # The form is how an admin raises, lowers, or removes a budget (ADR 0028), and
    # `universes#update` is a `PATCH` inside a universe, so the guard counts it like
    # any other mutation. The consequence is worth pinning rather than leaving to be
    # discovered: an admin who sets a budget of 1 spends it on their own settings
    # save, and the save that would raise it again is refused until the window
    # passes. That is the ADR's rule — the guard runs after authorization on every
    # universe-scoped write — and the window is a minute, so nobody is locked out.
    @universe.update!(mutation_limit: 1)
    exhaust_mutation_budget(@universe, @user, count: 1)

    patch universe_url(@universe), params: { universe: { mutation_limit: "30" } }, as: :json

    assert_response :too_many_requests
    assert_equal 1, @universe.reload.mutation_limit
  end

  test "the budget counts every mutating verb, on member and collection routes alike" do
    character = characters(:character_one)
    @universe.update!(mutation_limit: 1)

    # The member route is reached by `patch`/`delete` and the collection route by
    # `post`, so one budget of 1 is spent here and refuses all three verbs
    # afterwards — including the member `post` that no route answers, which is
    # what a 404 would otherwise have proved instead.
    patch universe_character_path(universe_slug: @universe.slug, id: character),
      params: { character: { name: "Renamed" } }, as: :json
    assert_response :ok

    delete universe_character_path(universe_slug: @universe.slug, id: character), as: :json
    assert_response :too_many_requests

    post universe_characters_path(universe_slug: @universe.slug),
      params: { character: { name: "Also refused" } }, as: :json
    assert_response :too_many_requests

    assert_equal "Renamed", character.reload.name, "a refused mutation must not have written"
  end

  # --- the configured limit --------------------------------------------------

  test "an admin's configured limit is the one that applies" do
    @universe.update!(mutation_limit: 1)

    post universe_characters_path(universe_slug: @universe.slug),
      params: { character: { name: "First" } }, as: :json
    assert_response :created

    post universe_characters_path(universe_slug: @universe.slug),
      params: { character: { name: "Second" } }, as: :json
    assert_response :too_many_requests
  end

  test "a null limit means no limit at all" do
    @universe.update!(mutation_limit: nil)
    assert @universe.mutations_unlimited?

    exhaust_mutation_budget(@universe, @user, count: 500)

    post universe_characters_path(universe_slug: @universe.slug),
      params: { character: { name: "Written freely" } }, as: :json

    assert_response :created
  end

  # --- the two refusal contracts --------------------------------------------

  test "the HTML flow is redirected back with an explanation" do
    exhaust_mutation_budget(@universe, @user, count: @universe.mutation_limit)

    post universe_relations_path(universe_slug: @universe.slug),
      params: { relation: { from_name: "A", to_name: "B" } }

    assert_redirected_to universe_url(@universe)
    assert_equal I18n.t("errors.mutation_throttled"), flash[:alert]
  end

  test "a JSON-only controller answers a bare 429 the modal can read" do
    exhaust_mutation_budget(@universe, @user, count: @universe.mutation_limit)

    post universe_characters_path(universe_slug: @universe.slug),
      params: { character: { name: "Refused" } }, as: :json

    assert_response :too_many_requests
    assert_empty response.body
  end

  test "the refusal is translated" do
    # The language is a signed browser cookie (`AppLocale`) and `switch_locale`
    # sets `I18n.locale` from it on every request, so a test cannot reach Spanish
    # by wrapping the call in `I18n.with_locale` — the around_action overwrites
    # it. The cookie is written by the application's own settings `PATCH`, which
    # is how a browser gets it, rather than by signing a value here: an
    # integration test's cookie jar is a `Rack::Test::CookieJar`, which has no
    # `signed` writer for `AppLocale.write` to use.
    patch settings_path, params: { locale: "es" }

    exhaust_mutation_budget(@universe, @user, count: @universe.mutation_limit)

    post universe_relations_path(universe_slug: @universe.slug),
      params: { relation: { from_name: "A", to_name: "B" } }

    assert_equal "Estás haciendo cambios demasiado rápido en este universo. Espera un momento e inténtalo de nuevo.",
      flash[:alert]
  end
end
