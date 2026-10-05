class User < ApplicationRecord
  include HasSlug

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :owned_universes, class_name: "Universe", foreign_key: :owner_id, inverse_of: :owner, dependent: :restrict_with_exception
  has_many :universe_memberships, dependent: :destroy
  # A draft is one person's pending changes, so a person owns them the same way
  # they own their sessions. Nothing deletes a user today; the association is here
  # so the row cannot outlive its author if that ever changes.
  has_many :drafts, dependent: :destroy
  # A notification is written to one account, so a person keeps it the way they keep
  # their drafts and their sessions. Nothing deletes a user today; the association is
  # here so a row addressed to somebody who no longer exists cannot outlive them.
  has_many :notifications, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # The universes this person collaborates in: the ones they own plus the ones they
  # hold a membership in.
  #
  # **It is a method rather than `has_many :universes, through: :universe_memberships`
  # because the owner is not a membership row.** `UniverseMembership` refuses to
  # record one (`user_is_not_universe_owner`), so an association through memberships
  # answers "the universes I was invited to" and silently leaves out every universe
  # this person founded — and the founder is the person with the most to be reminded
  # of. An ordinary reader asking "which universes am I in?" has no reason to know
  # that one of the two ways in has no row of its own, so the union is done here
  # rather than asked of each caller.
  #
  # **`accessible_universes` is a different question and stays separate.** It is what
  # the reader may *open*, which for a public universe is every universe on the
  # platform and for a private one the owner and its members — a superset that this
  # does not approximate. Neither is derived from the other, so a caller has to say
  # which one it wants.
  def universes
    Universe.where(id: owned_universe_ids | universe_memberships.pluck(:universe_id))
  end

  def accessible_universes
    Universe.visible_to(self)
  end
end
