# An API credential: a bearer token bound to a user and to an explicit set of
# universes.
#
# The bearer value is shown once when the token is created and is never stored:
# only `token_digest` is kept, the same discipline as `password_digest`. A short
# leading prefix (`token_prefix`) is stored only so a presented token can be
# looked up before its digest is checked; the prefix alone is not a credential.
#
# A token is refused once `revoked_at` is set, and `last_used_at` is touched on
# every successful authentication.
class ApiToken < ApplicationRecord
  # How many leading characters of the bearer token are stored (unhashed) so a
  # presented token can be located before its digest is verified.
  TOKEN_PREFIX_LENGTH = 8

  belongs_to :user
  has_many :api_token_universes, dependent: :delete_all
  has_many :universes, through: :api_token_universes

  validates :name, presence: true
  validates :token_digest, presence: true
  validates :token_prefix, presence: true, uniqueness: true

  # The bearer credential, shown once at creation and never written to the table.
  attr_accessor :token

  before_validation :digest_token, if: :token

  # Finds a non-revoked token by its prefix and verifies the bearer value against
  # the stored digest. Touches `last_used_at` on success. Returns the token, or
  # nil when there is nothing to authenticate.
  def self.authenticate(bearer_token)
    return unless bearer_token.present?

    record = find_by(token_prefix: bearer_token[0, TOKEN_PREFIX_LENGTH], revoked_at: nil)
    return unless record && record.authenticates?(bearer_token)

    record.update_column(:last_used_at, Time.current)
    record
  end

  # Revokes the token so it can no longer authenticate.
  def revoke!
    update!(revoked_at: Time.current)
  end

  def active?
    revoked_at.blank?
  end

  # Verifies a bearer value against the stored digest, the same way
  # `has_secure_password` authenticates a password.
  def authenticates?(bearer_token)
    BCrypt::Password.new(token_digest) == bearer_token
  end

  private

    def digest_token
      self.token_prefix = token[0, TOKEN_PREFIX_LENGTH]
      self.token_digest = BCrypt::Password.create(token)
    end
end
