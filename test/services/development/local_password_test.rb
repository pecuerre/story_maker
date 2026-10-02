require "test_helper"

# The development password used to be a literal in `db/data/*/users.yml`. These
# cases pin the replacement: a value comes from the environment when one is
# configured, and a generated value is used — never a tracked fallback — when it
# is not.
class LocalPasswordTest < ActiveSupport::TestCase
  test "a configured value is used verbatim" do
    password = Development::LocalPassword.resolve(env: { Development::LocalPassword::ENV_KEY => "chosen-login" })

    assert_equal "chosen-login", password.value
    assert_not password.generated?
  end

  test "a generated value is used when the variable is absent" do
    password = Development::LocalPassword.resolve(env: {})

    assert password.generated?
    assert_not_empty password.value
  end

  # A blank value is a missing value, not a password: `UNIVERSE_MAKER_DEV_PASSWORD=`
  # in a shell or a `.env` must not create an account whose password is empty.
  test "a blank configured value is treated as absent" do
    [ nil, "", "   " ].each do |blank|
      password = Development::LocalPassword.resolve(env: { Development::LocalPassword::ENV_KEY => blank })

      assert password.generated?, "#{blank.inspect} should not be accepted as a password"
      assert_not_equal "", password.value
    end
  end

  test "each resolution without a configured value produces a different value" do
    values = Array.new(3) { Development::LocalPassword.resolve(env: {}).value }

    assert_equal values.uniq.length, values.length,
      "A generated development password must not repeat: a shared value would be a constant."
  end

  test "the generated value is long enough to be unguessable and short enough to type" do
    assert_equal Development::LocalPassword::GENERATED_BYTES * 2, Development::LocalPassword.resolve(env: {}).value.length
  end

  test "the export command quotes a value that a shell would otherwise split" do
    password = Development::LocalPassword.new("two words", generated: true)

    assert_equal "export #{Development::LocalPassword::ENV_KEY}=two\\ words", password.export_command
  end

  test "the variable name is explicit rather than a bare guess" do
    assert_equal "UNIVERSE_MAKER_DEV_PASSWORD", Development::LocalPassword::ENV_KEY
  end
end
