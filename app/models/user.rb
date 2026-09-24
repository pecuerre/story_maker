class User < ApplicationRecord
  include HasSlug

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :owned_universes, class_name: "Universe", foreign_key: :owner_id, inverse_of: :owner, dependent: :restrict_with_exception
  has_many :universe_memberships, dependent: :destroy
  has_many :universes, through: :universe_memberships

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def accessible_universes
    Universe.visible_to(self)
  end
end
