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

  test "reset mail is written in the locale it is asked for" do
    # The delivery job runs on a thread with no `I18n.locale` of its own, so the
    # locale travels as an argument rather than being read from the thread.
    mail = PasswordsMailer.reset(@user, locale: :es)

    assert_equal "Restablece tu contraseña", mail.subject
    # `body.encoded` is quoted-printable, so a Spanish word arrives escaped and
    # could not be matched as text. The decoded part is what a reader receives.
    assert_match "restablecer tu contraseña", mail.text_part.body.decoded
    # The duration is Rails' own string, translated through the Spanish block in
    # `es.yml` rather than left in English.
    assert_match "Este enlace caducará en", mail.text_part.body.decoded
  end

  test "reset mail falls back to the default locale when none is given" do
    # This is the real shape of a queued delivery today: the job has no locale of
    # its own, so the message is English. Recorded in ADR 0016 as the known limit
    # of a browser-owned language rather than silently asserted as Spanish.
    assert_equal :en, I18n.locale
    assert_equal "Reset your password", PasswordsMailer.reset(@user).subject
  end
end
