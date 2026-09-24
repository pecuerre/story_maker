class UniverseMembership < ApplicationRecord
  ACCESS_LEVELS = {
    read: 1,
    write: 2,
    admin: 3
  }.freeze
  LEVELS = ACCESS_LEVELS

  belongs_to :universe
  belongs_to :user

  enum :access_level, ACCESS_LEVELS

  validates :access_level, presence: true, inclusion: { in: ACCESS_LEVELS.keys.map(&:to_s) }
  validates :user_id, uniqueness: { scope: :universe_id }
  validate :user_is_not_universe_owner
  before_validation :set_default_access_level, on: :create

  def role
    access_level
  end

  def role=(value)
    self.access_level = value
  end

  def at_least?(level)
    current_level = ACCESS_LEVELS[access_level.to_s.to_sym] || 0
    required_level = ACCESS_LEVELS[level.to_s.to_sym] || 0
    current_level >= required_level
  end

  def readable?
    at_least?(:read)
  end

  def writable?
    at_least?(:write)
  end

  def administrable?
    at_least?(:admin)
  end

  private

    def set_default_access_level
      self.access_level = :read if access_level.nil?
    end

    def user_is_not_universe_owner
      return if user.nil? || universe.nil? || user_id != universe.owner_id

      errors.add(:user, "is the universe owner and already has admin access")
    end
end
