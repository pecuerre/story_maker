class PasswordsMailer < ApplicationMailer
  # A password reset is written in the language of the request that asked for
  # it, so the locale is captured here and re-applied around the build. The
  # message is actually rendered later, by the delivery job, on a thread that
  # knows nothing about the reader's browser — so `I18n.locale` at build time is
  # only the request's locale when the mail is delivered inline. Until a
  # language follows an account (a `User` column, deliberately out of scope), a
  # queued reset falls back to the default locale; that limitation is recorded
  # in ADR 0016 rather than papered over here.
  def reset(user, locale: I18n.locale)
    @user = user
    I18n.with_locale(locale) do
      mail subject: t("passwords_mailer.reset.subject"), to: user.email_address
    end
  end
end
