require "test_helper"

# The per-token ceiling: protected from creation, `NULL` is "no limit at all",
# and `0` or a fractional number is refused.
class ApiTokenTest < ActiveSupport::TestCase
  setup do
    @token = api_tokens(:token_one)
  end

  test "a new token is limited from creation by the default ceiling" do
    token = ApiToken.create!(user: users(:user_one), name: "Limited from creation",
      token: "epsilon-api-token-one")

    assert_equal ApiToken::DEFAULT_MUTATION_LIMIT, token.mutation_limit
    refute token.mutations_unlimited?
  end

  test "mutation_limit is nil or a positive integer" do
    assert @token.valid?

    @token.mutation_limit = nil
    assert @token.valid?, "NULL means no limit at all and must be storable"

    @token.mutation_limit = 1
    assert @token.valid?

    @token.mutation_limit = 0
    refute @token.valid?, "zero mutations is a closed token, not an unlimited one"

    @token.mutation_limit = -1
    refute @token.valid?

    @token.mutation_limit = 1.5
    refute @token.valid?
  end

  test "mutations_unlimited answers the stored NULL, not the fallback" do
    refute @token.mutations_unlimited?

    @token.update!(mutation_limit: nil)
    assert @token.reload.mutations_unlimited?
  end
end
