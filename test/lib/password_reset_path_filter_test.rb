require "test_helper"

class PasswordResetPathFilterTest < ActiveSupport::TestCase
  test "redacts password reset tokens from filtered request paths" do
    request = ActionDispatch::Request.new(
      Rack::MockRequest.env_for("/passwords/secret-token/edit")
    )

    assert_equal "/passwords/[FILTERED]/edit", request.filtered_path
  end

  test "does not redact the password reset form path" do
    request = ActionDispatch::Request.new(
      Rack::MockRequest.env_for("/passwords/new")
    )

    assert_equal "/passwords/new", request.filtered_path
  end
end
