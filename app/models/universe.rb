class Universe < ApplicationRecord
  MENU_COUNT_ASSOCIATIONS = %i[characters relations locations events items ownerships].freeze

  include HasSlug

  after_destroy_commit :expire_menu_counts
  validates :name, presence: true
  validates :owner, presence: true
  validates :private, inclusion: { in: [ true, false ] }

  scope :visible_to, ->(user) {
    if user
      membership_ids = UniverseMembership.where(user_id: user.id).select(:universe_id)
      where(private: false).or(where(owner_id: user.id)).or(where(id: membership_ids))
    else
      where(private: false)
    end
  }

  scope :readable_by, ->(user) { visible_to(user) }

  scope :writable_by, ->(user) {
    return none unless user

    membership_ids = UniverseMembership.where(
      user_id: user.id,
      access_level: [ UniverseMembership::ACCESS_LEVELS[:write], UniverseMembership::ACCESS_LEVELS[:admin] ]
    ).select(:universe_id)
    where(private: false).or(where(owner_id: user.id)).or(where(id: membership_ids))
  }

  scope :administrated_by, ->(user) {
    return none unless user

    membership_ids = UniverseMembership.where(
      user_id: user.id,
      access_level: UniverseMembership::ACCESS_LEVELS[:admin]
    ).select(:universe_id)
    where(owner_id: user.id).or(where(id: membership_ids))
  }

  belongs_to :owner, class_name: "User"
  has_many :memberships, class_name: "UniverseMembership", dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :stories, dependent: :destroy
  has_many :sections, through: :stories
  has_many :item_tags, dependent: :destroy
  has_many :items, dependent: :destroy
  has_many :location_tags, dependent: :destroy
  has_many :locations, dependent: :destroy
  has_many :character_tags, dependent: :destroy
  has_many :characters, dependent: :destroy
  has_many :relation_tags, dependent: :destroy
  has_many :relations, dependent: :destroy
  has_many :ownership_tags, dependent: :destroy
  has_many :ownerships, dependent: :destroy
  has_many :event_tags, dependent: :destroy
  has_many :events, dependent: :destroy

  # Only an explicit false grants the public baseline. Treating any other
  # value (including legacy NULL data) as private prevents ambiguous records
  # from failing open while an owner or explicit member still retains access.
  def public?
    self[:private] == false
  end

  # The effective level for a user. Public universes give every signed-in user
  # write access; private universes use the explicit membership level. The
  # owner is always an admin, even when no membership row exists.
  def access_level_for(user)
    return nil unless user

    return "admin" if owner_id == user.id

    membership = memberships.find_by(user_id: user.id)
    return "admin" if membership&.access_level == "admin"
    return "write" if public?

    membership&.access_level
  end

  def readable_by?(user)
    return true if public?

    access_level_for(user).present?
  end

  def writable_by?(user)
    return false unless user

    %w[write admin].include?(access_level_for(user))
  end

  def administrable_by?(user)
    user.present? && access_level_for(user) == "admin"
  end

  alias_method :administered_by?, :administrable_by?

  def menu_counts
    MenuCountCache.fetch(MenuCountCache.key(:universe, id), connection: self.class.connection) do
      MENU_COUNT_ASSOCIATIONS.to_h do |association|
        [ association, public_send(association).count ]
      end
    end
  end

  def to_param
    slug
  end

  private
    def expire_menu_counts
      MenuCountCache.expire(:universe, id)
    end
end
