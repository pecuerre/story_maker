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
#
# `mutation_limit` is how many mutations one account may make with this token
# per `Universe::MUTATION_LIMIT_WINDOW`, counted in its own cache counter inside
# the universe's budget. The column default protects a token from creation,
# `NULL` is "no limit at all" for a token an operator has opened up, and `0` is
# refused because zero mutations and no limit are different settings. Reads are
# counted in a separate counter against the same ceiling, so a read flood never
# spends the mutation budget and vice versa.
class ApiToken < ApplicationRecord
  # How many leading characters of the bearer token are stored (unhashed) so a
  # presented token can be located before its digest is checked.
  TOKEN_PREFIX_LENGTH = 8

  # How many mutations one account may make with this token per minute before
  # the per-token throttle refuses it. The same order as the universe's default
  # budget; a token is never unlimited just because nobody chose a number.
  DEFAULT_MUTATION_LIMIT = 60

  belongs_to :user
  has_many :api_token_universes, dependent: :delete_all
  has_many :universes, through: :api_token_universes

  # The tokens one account holds for one universe: what the management page
  # lists and what revoking acts on. `distinct` because the join could
  # otherwise repeat a token once per grant row.
  scope :for_universe, ->(universe) {
    joins(:api_token_universes)
      .where(api_token_universes: { universe: universe })
      .distinct
  }

  validates :name, presence: true
  validates :token_digest, presence: true
  validates :token_prefix, presence: true, uniqueness: true
  # The same rule the universe's budget carries: `NULL` means unlimited, `0`
  # means closed and is refused, and anything fractional is refused too.
  validates :mutation_limit,
    numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # How many mutations this token may still make this window, falling back to
  # the default when the column stores nothing. A token an administrator has
  # deliberately opened up stores `NULL`.
  def mutation_limit
    self[:mutation_limit] || DEFAULT_MUTATION_LIMIT
  end

  # Whether this token has no mutation ceiling at all — deliberately different
  # from a high number, because `NULL` is the stored form of "no limit".
  def mutations_unlimited?
    self[:mutation_limit].nil?
  end

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

  def revoked?
    revoked_at.present?
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
