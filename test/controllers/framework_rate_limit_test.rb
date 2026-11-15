require "test_helper"

# The limits declared with the framework's own `rate_limit` macro rather than
# with `MutationThrottle`: sign-in, password reset, and the story-interchange
# download.
#
# They are here because a limit nobody tests is indistinguishable from a limit
# that does not exist. `rate_limit` resolves its store when the macro is
# declared, so these are wired to whatever `config.cache_store` named at boot
# and a test cannot install a different one — which is why that setting is a
# counting `:memory_store` and why this file clears the store instead of
# replacing it.
#
# `ATTEMPTS_ALLOWED` and `EXPORT_ATTEMPTS_ALLOWED` mirror `rate_limit to: 10` in
# the two session controllers and `rate_limit to: 5` in
# `StoryInterchangeExportsController`. The macro keeps its arguments inside a
# `before_action` lambda rather than as readable attributes, so the numbers are
# repeated here rather than reflected: raising a limit is a security decision,
# and it should fail this file when it happens rather than be absorbed by a test
# that reads whatever the controller says.
class FrameworkRateLimitTest < ActionDispatch::IntegrationTest
  ATTEMPTS_ALLOWED = 10
  EXPORT_ATTEMPTS_ALLOWED = 5

  setup do
    clear_all_counters
    @user = users(:user_one)
    @universe = universes(:universe_one)
    @story = stories(:story_one)
  end

  # --- sign-in ---------------------------------------------------------------

  test "sign-in refuses the attempt past the limit" do
    ATTEMPTS_ALLOWED.times { attempt_sign_in }

    assert_equal I18n.t("sessions.failed"), flash[:alert],
      "every attempt inside the limit is a normal failure, not a refusal"

    attempt_sign_in

    assert_redirected_to new_session_path
    assert_equal I18n.t("errors.rate_limited"), flash[:alert]
  end

  test "sign-in refuses a correct password past the limit too" do
    ATTEMPTS_ALLOWED.times { attempt_sign_in(password: "password") }
    attempt_sign_in(password: "password")

    # The refusal is on the attempt, not on the credentials, so a correct
    # password arriving late is refused like any other. Without this, a throttle
    # that only counted failures would pass every test above it.
    assert_redirected_to new_session_path
    assert_equal I18n.t("errors.rate_limited"), flash[:alert]
  end

  test "the attempt on the limit is the one that still works" do
    (ATTEMPTS_ALLOWED - 1).times { attempt_sign_in }
    attempt_sign_in(password: "password")

    assert cookies["session_id"].present?,
      "the last allowed attempt must reach the sign-in action rather than the refusal: the " \
      "limit spends its budget before it compares, so an off-by-one would lock out the " \
      "tenth attempt instead of the eleventh"

    # The redirect is what separates the two branches here, not the flash: nine
    # failures earlier in this test left an alert behind that a successful sign-in
    # does not clear, so asserting on `flash[:alert]` would read the stale one.
    assert_redirected_to root_path
  end

  # --- password reset --------------------------------------------------------

  test "password reset refuses the attempt past the limit" do
    ATTEMPTS_ALLOWED.times { attempt_password_reset }

    assert_equal I18n.t("passwords.instructions_sent"), flash[:notice],
      "every request inside the limit is answered normally"

    attempt_password_reset

    assert_redirected_to new_password_path
    assert_equal I18n.t("errors.rate_limited"), flash[:alert]
  end

  test "the password reset answers the same address for everybody" do
    # The create action never says whether the address is known, so the limit must
    # not either — a refusal that distinguished them would confirm an account
    # exists.
    (ATTEMPTS_ALLOWED).times { attempt_password_reset(email_address: "nobody@example.com") }
    attempt_password_reset(email_address: "nobody@example.com")

    assert_redirected_to new_password_path
    assert_equal I18n.t("errors.rate_limited"), flash[:alert]
  end

  # --- the two counters are separate ----------------------------------------

  test "exhausting sign-in does not refuse a password reset" do
    (ATTEMPTS_ALLOWED + 1).times { attempt_sign_in }

    attempt_password_reset

    assert_redirected_to new_session_path
    assert_equal I18n.t("passwords.instructions_sent"), flash[:notice]
  end

  # --- interchange download --------------------------------------------------

  test "the interchange download refuses the request past the limit" do
    EXPORT_ATTEMPTS_ALLOWED.times do
      get download_url
      assert_response :success
    end

    get download_url

    assert_redirected_to universe_story_export_path(universe_slug: @universe.slug, story_id: @story)
    assert_equal I18n.t("errors.rate_limited"), flash[:alert]
  end

  test "a signed-in reader is counted apart from the address they share" do
    # The guest exhausts the address's budget; a reader who signs in from the
    # same address has their own, so a shared address is not one budget for
    # every signed-in member behind it.
    (EXPORT_ATTEMPTS_ALLOWED + 1).times { get download_url }
    assert_redirected_to universe_story_export_path(universe_slug: @universe.slug, story_id: @story)

    sign_in_as(@user)
    get download_url

    assert_response :success
  end

  private
    def attempt_sign_in(email_address: nil, password: "wrong-password")
      post session_path, params: {
        email_address: email_address || @user.email_address,
        password: password
      }
    end

    def attempt_password_reset(email_address: nil)
      post passwords_path, params: { email_address: email_address || @user.email_address }
    end

    def download_url
      universe_story_export_interchange_path(universe_slug: @universe.slug, story_id: @story)
    end
end
