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

  # A real cropped-square `data:` URL, because these cases submit an actual photo and
  # a mutation that is refused before the action runs would not notice. The one
  # pixel is the smallest thing `PhotoProcessing` accepts.
  def square_data_url
    @square_data_url ||= "data:image/png;base64,#{Base64.strict_encode64(one_pixel_png)}"
  end

  def one_pixel_png
    Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
  end

  # The theme the last response rendered onto the root element, which is what a
  # browser would paint. Asked of the document rather than of the cookie because an
  # integration test's jar is not the signed jar `AppTheme.read` expects.
  def rendered_theme
    Nokogiri::HTML(response.body).at_css("html")["data-bs-theme"]
  end

  # `universe_one` is owned by `user_one`, so a grant can name anybody else. The
  # second account has to be built rather than taken from the fixtures: the only
  # membership fixture sits on the far side of a universe boundary on purpose.
  def another_account
    @another_account ||= User.create!(name: "Third Account", email_address: "three@example.com",
      password: "password")
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

  # --- the per-group sub-limits -----------------------------------------------

  test "a photo over the photo ceiling is refused while the universe budget is untouched" do
    # The point of the slice: a photo ceiling that bites at a number the universe's
    # own budget is nowhere near. 60 mutations a minute is left in the universe
    # budget and the second upload is still refused, because the group is a ceiling
    # inside it rather than a share of it.
    @universe.update!(photo_mutation_limit: 1)

    patch universe_character_path(universe_slug: @universe.slug, id: characters(:character_one)),
      params: { character: { photo_data: square_data_url } }, as: :json
    assert_response :ok

    patch universe_character_path(universe_slug: @universe.slug, id: characters(:character_one)),
      params: { character: { photo_data: square_data_url } }, as: :json

    assert_response :too_many_requests
    assert_equal 2, mutation_group_count(@universe, @user, :photo)
    assert_equal 2, mutation_budget_count(@universe, @user),
      "a refused group still counts as a mutation of this universe, as ADR 0028 counts every attempt"
  end

  test "a grouped mutation spends the universe budget as well as its own" do
    # The sub-limit reading of ADR 0029: the group's number is what binds first
    # *inside* the universe's budget, not instead of it. A test that only refused on
    # the group would pass under either reading, so this one counts both.
    @universe.update!(photo_mutation_limit: 10)

    patch universe_character_path(universe_slug: @universe.slug, id: characters(:character_one)),
      params: { character: { photo_data: square_data_url } }, as: :json

    assert_response :ok
    assert_equal 1, mutation_budget_count(@universe, @user)
    assert_equal 1, mutation_group_count(@universe, @user, :photo)
  end

  test "an ordinary mutation spends the universe budget and no group" do
    @universe.update!(photo_mutation_limit: 1)

    post universe_characters_path(universe_slug: @universe.slug),
      params: { character: { name: "No photo here" } }, as: :json

    assert_response :created
    assert_equal 1, mutation_budget_count(@universe, @user)
    assert_equal 0, mutation_group_count(@universe, @user, :photo),
      "a rename with no photo is not an upload and must not spend the photo ceiling"
  end

  test "an empty photo field does not spend the photo ceiling" do
    # Every editor renders the photo field, so every ordinary mutation submits it
    # empty. Charging the photo ceiling for those would make the ceiling mean
    # "edits", which is what the universe budget already counts.
    @universe.update!(photo_mutation_limit: 1)

    2.times do
      patch universe_character_path(universe_slug: @universe.slug, id: characters(:character_one)),
        params: { character: { name: "Renamed", photo_data: "" } }, as: :json
      assert_response :ok
    end

    assert_equal 0, mutation_group_count(@universe, @user, :photo)
  end

  test "clearing a photo spends no photo ceiling, because dropping an image writes none" do
    @universe.update!(photo_mutation_limit: 1)

    patch universe_character_path(universe_slug: @universe.slug, id: characters(:character_one)),
      params: { character: { remove_photo: "1" } }, as: :json

    assert_response :ok
    assert_equal 0, mutation_group_count(@universe, @user, :photo)
  end

  test "a membership grant over the access ceiling is refused" do
    @universe.update!(membership_mutation_limit: 1)

    # Two grants: the first is under the ceiling, the second is over it. Memberships
    # is the HTML flow, so a refusal is the redirect and its alert.
    post universe_memberships_path(universe_slug: @universe.slug),
      params: { membership: { email_address: users(:user_two).email_address, access_level: "read" } }
    assert_response :see_other

    post universe_memberships_path(universe_slug: @universe.slug),
      params: { membership: { email_address: another_account.email_address, access_level: "read" } }
    assert_response :see_other
    assert_equal I18n.t("errors.mutation_throttled"), flash[:alert]
    assert_equal 0, @universe.memberships.where(user_id: another_account.id).count,
      "a refused grant must not have written"
  end

  test "an access change and a removal both spend the access ceiling" do
    # `MembershipsController` is admin-gated in its entirety, and a level change is as
    # much a grant as the first row was, so all three of its writes are one group.
    membership = @universe.memberships.create!(user: users(:user_two), access_level: "read")
    @universe.update!(membership_mutation_limit: 1)

    patch universe_membership_path(universe_slug: @universe.slug, id: membership),
      params: { membership: { access_level: "admin" } }
    assert_response :see_other
    assert_equal 1, mutation_group_count(@universe, @user, :membership)

    delete universe_membership_path(universe_slug: @universe.slug, id: membership)
    assert_response :see_other
    assert_equal I18n.t("errors.mutation_throttled"), flash[:alert]
  end

  test "a discussion reply over the reply ceiling is refused and writes nothing" do
    @universe.update!(discussion_mutation_limit: 1)
    discussion = characters(:character_one).find_or_create_discussion

    2.times do
      post universe_discussion_messages_path(universe_slug: @universe.slug, discussion_id: discussion),
        params: { discussion_message: { body: "A reply from the throttled account" } }
    end

    assert_response :see_other
    assert_equal I18n.t("errors.mutation_throttled"), flash[:alert]
    assert_equal 1, discussion.messages.reload.count,
      "only the first reply was written; the refused one saved nothing"
  end

  test "a group's null limit is no limit for that group alone" do
    # The answers are deliberately independent: an admin can leave a universe's
    # content budget open while keeping a ceiling on uploads, and a cleared upload
    # ceiling says nothing about the reply ceiling beside it.
    @universe.update!(mutation_limit: nil, photo_mutation_limit: nil, discussion_mutation_limit: 1)
    discussion = characters(:character_one).find_or_create_discussion

    3.times do
      patch universe_character_path(universe_slug: @universe.slug, id: characters(:character_one)),
        params: { character: { photo_data: square_data_url } }, as: :json
      assert_response :ok, "an unlimited group must not refuse, whatever the other budgets say"
    end

    2.times do
      post universe_discussion_messages_path(universe_slug: @universe.slug, discussion_id: discussion),
        params: { discussion_message: { body: "Still bounded" } }
    end

    assert_response :see_other, "the reply ceiling is its own setting and still applies"
  end

  test "a zero group limit is a field error rather than a silent no-op" do
    universe = Universe.new(owner: @user, name: "Zero", photo_mutation_limit: 0)

    assert_not universe.valid?
    assert_includes universe.errors[:photo_mutation_limit], "must be greater than 0"
  end

  # --- universe creation, the one group with no universe -----------------------

  test "universe creation over the platform ceiling is refused with its own sentence" do
    exhaust_mutation_group(nil, @user, :universe_creation, count: PlatformSetting::DEFAULT_UNIVERSE_CREATION_LIMIT)

    assert_no_difference -> { Universe.count } do
      post universes_path, params: { universe: { name: "Refused before it exists" } }
    end

    assert_response :see_other
    assert_equal I18n.t("errors.mutation_throttled_platform"), flash[:alert]
    # There is no universe to go back to, so the fallback is the list the form was
    # opened from.
    assert_redirected_to root_path
  end

  test "an operator's configured creation limit is the one that applies" do
    setting = PlatformSetting.create!(universe_creation_limit: 1)

    post universes_path, params: { universe: { name: "The first one" } }
    assert_response :found
    assert_equal 1, Universe.where(name: "The first one").count

    post universes_path, params: { universe: { name: "The second one" } }
    assert_response :see_other
    assert_equal I18n.t("errors.mutation_throttled_platform"), flash[:alert]
    assert_equal 0, Universe.where(name: "The second one").count
    assert_equal 1, setting.reload.universe_creation_limit
  end

  test "a null creation limit is no limit" do
    PlatformSetting.create!(universe_creation_limit: nil)
    exhaust_mutation_group(nil, @user, :universe_creation, count: 500)

    post universes_path, params: { universe: { name: "Written freely" } }

    assert_response :found
    assert_equal 1, Universe.where(name: "Written freely").count
  end

  test "creating a universe spends no universe budget, because there is no universe yet" do
    post universes_path, params: { universe: { name: "Counted against nothing" } }

    assert_response :found
    assert_equal 1, mutation_group_count(nil, @user, :universe_creation)
    assert_equal 0, mutation_budget_count(@universe, @user)
  end

  test "a guest cannot spend an account's creation budget" do
    sign_out
    exhaust_mutation_group(nil, @user, :universe_creation, count: PlatformSetting::DEFAULT_UNIVERSE_CREATION_LIMIT)

    assert_no_difference -> { mutation_group_count(nil, @user, :universe_creation) } do
      post universes_path, params: { universe: { name: "Not signed in" } }
    end

    # The refusal comes from the sign-in requirement, not from the throttle.
    assert_response :found
    assert_redirected_to new_session_path
  end

  # --- the platform limit is the operator's to set ---------------------------

  test "an operator sets the creation limit and it is stored once" do
    operator = users(:platform_operator)
    sign_in_as(operator)

    patch settings_path, params: { universe_creation_limit: "9" }

    assert_response :see_other
    assert_equal 9, PlatformSetting.current.universe_creation_limit
    assert_equal 1, PlatformSetting.count, "the setting is one row, not one per save"
  end

  test "clearing the field stores no limit rather than nothing" do
    operator = users(:platform_operator)
    PlatformSetting.create!(universe_creation_limit: 3)
    sign_in_as(operator)

    patch settings_path, params: { universe_creation_limit: "" }

    assert_response :see_other
    assert PlatformSetting.current.universe_creations_unlimited?
  end

  test "a refused limit stores nothing and reports why" do
    operator = users(:platform_operator)
    PlatformSetting.create!(universe_creation_limit: 3)
    sign_in_as(operator)

    patch settings_path, params: { universe_creation_limit: "many" }

    assert_response :see_other
    assert_match(/number/, flash[:alert])
    assert_equal 3, PlatformSetting.current.reload.universe_creation_limit
  end

  test "a request that refuses a preference does not apply the limit it also carried" do
    # The all-or-nothing rule the three browser preferences already followed, now
    # spanning the two halves of this action: half of what an operator asked for and
    # a success message for the rest cannot be acted on.
    operator = users(:platform_operator)
    sign_in_as(operator)

    patch settings_path, params: { theme: "chartreuse", universe_creation_limit: "7" }

    assert_response :see_other
    assert_equal I18n.t("settings.flash.theme_unknown"), flash[:alert]
    assert_equal PlatformSetting::DEFAULT_UNIVERSE_CREATION_LIMIT,
      PlatformSetting.current.universe_creation_limit

    follow_redirect!
    assert_equal "light", rendered_theme,
      "the refused theme was not stored either, so the page still renders the default"
  end

  test "a plain reader has no limits section and cannot save the limit" do
    sign_out
    get settings_path(section: "limits")

    assert_response :success
    assert_select "nav.settings-navigation a", text: "Limits", count: 0
    assert_select "input[name=universe_creation_limit]", count: 0

    sign_in_as(users(:user_one))
    get settings_path(section: "limits")

    assert_response :success
    assert_select "input[name=universe_creation_limit]", count: 0

    patch settings_path, params: { universe_creation_limit: "7" }

    assert_response :forbidden
    assert_equal PlatformSetting::DEFAULT_UNIVERSE_CREATION_LIMIT,
      PlatformSetting.current.universe_creation_limit
  end

  test "an operator sees the limits section" do
    sign_in_as(users(:platform_operator))

    get settings_path(section: "limits")

    assert_response :success
    assert_select "nav.settings-navigation a", text: "Limits"
    assert_select "input[name=universe_creation_limit][value=?]",
      PlatformSetting::DEFAULT_UNIVERSE_CREATION_LIMIT.to_s
  end

  test "an omitted limit parameter leaves the stored one alone" do
    # The blank-means-no-limit rule needs `key?` rather than `present?`, and this is
    # the case that would break if the two were confused: a save of another
    # preference must not clear a number nobody mentioned.
    operator = users(:platform_operator)
    PlatformSetting.create!(universe_creation_limit: 4)
    sign_in_as(operator)

    patch settings_path, params: { theme: "dark" }

    assert_response :see_other
    assert_equal 4, PlatformSetting.current.reload.universe_creation_limit
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
