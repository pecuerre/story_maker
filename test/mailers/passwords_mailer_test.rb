require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:user_one)
  end

  test "reset mail uses the configured sender and HTTPS URL" do
    mail = PasswordsMailer.reset(@user)

    assert_equal [ "no-reply@test.example" ], mail.from
    assert_equal [ @user.email_address ], mail.to
    assert_match %r{https://test\.example/passwords/}, mail.body.encoded
    assert_no_match(/example\.com/, mail.body.encoded)
  end

  test "reset mail includes both text and HTML parts" do
    mail = PasswordsMailer.reset(@user)

    assert mail.multipart?
    assert_equal 2, mail.parts.size
  end
end
