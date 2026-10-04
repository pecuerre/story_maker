class Universe < ApplicationRecord
  MENU_COUNT_ASSOCIATIONS = %i[characters relations locations events items ownerships].freeze

  # The one value that decides how a change reaches a record in this universe:
  # `direct` writes straight through, while the other two remember the change for
  # its author to apply instead. The stored string is not the interface — read the
  # mode through the predicates below, so a new value cannot arrive with callers
  # still comparing the string themselves and answering "not direct" without
  # saying what it is.
  COLLABORATION_MODES = %w[direct wikipedia github].freeze

  include HasSlug
  include HasPhoto
  include SoftDeletable
  include Searchable

  # A universe's slug appears in the stored path of every document under it, so a
  # rename makes all of them dead links. This record's own document is re-indexed
  # like any other update; the rest of the universe is one bounded job rather
  # than a silent pile of 404s waiting for someone to remember a full reindex.
  searchable kind: "universe", title: :name, scope: :self
  after_update_commit :queue_search_reindex, if: :saved_change_to_slug?

  soft_deletes :stories, :characters, :locations, :items, :events, :relations, :ownerships,
    :character_tags, :location_tags, :item_tags, :event_tags, :relation_tags, :ownership_tags, :memberships

  after_destroy_commit :expire_menu_counts
  validates :name, presence: true
  validates :owner, presence: true
  validates :private, inclusion: { in: [ true, false ] }
  # The column's default and the validation are the same list on purpose. A mode
  # the application has no behaviour for is a field error an admin can answer,
  # rather than a universe whose writes quietly do the wrong thing.
  validates :collaboration_mode, inclusion: { in: COLLABORATION_MODES }
  # A universe slug is its public address (`/u/<slug>`) and is global, so
  # `HasSlug` deriving it from the name means two universes whose names slugify
  # alike collide. The partial unique index on `universes.slug` only sees live
  # rows, and it used to raise `ActiveRecord::RecordNotUnique` from inside an
  # ordinary create or update. This validation carries the same condition, so a
  # taken address is a field error the form can show and the author can answer
  # with a different slug.
  validates :slug, uniqueness: { conditions: -> { where(deleted_at: nil) } }

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
  # A thread belongs to one record and one universe. The record's own destroy
  # already takes its thread, so this is what covers the universe cascade: a
  # thread that outlived the record it was about would be an orphan row nothing
  # can reach.
  has_many :discussions, dependent: :destroy
  # A draft is authorized inside one universe, so the universe cascade covers it
  # for the same reason it covers a thread: a draft left behind would be an orphan
  # row holding changes against records that no longer exist.
  has_many :drafts, dependent: :destroy
  # A submission is authorized inside one universe, and its universe is validated
  # against its draft rather than trusted, so the cascade is what covers a row whose
  # universe was destroyed before its draft: a review request that outlived the draft it
  # reviews would be a row nobody can render.
  has_many :review_requests, dependent: :destroy
  has_many :stories, dependent: :destroy
  has_many :sections, through: :stories
  has_many :scenes, through: :stories
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

  def direct?
    collaboration_mode == "direct"
  end

  def wikipedia?
    collaboration_mode == "wikipedia"
  end

  def github?
    collaboration_mode == "github"
  end

  # Whether a change is remembered rather than written straight through. This is
  # the negation of `direct?` rather than `wikipedia? || github?` on purpose: a
  # mode this version does not know about counts as draft-based, so an
  # unrecognized value holds a change for an author to look at instead of
  # writing it. A missed change is recoverable; a written one is not.
  def draft_based?
    !direct?
  end

  # Only an explicit false grants the public baseline. Treating any other
  # value (including legacy NULL data) as private prevents ambiguous records
  # from failing open while an owner or explicit member still retains access.
  def public?
    self[:private] == false
  end

  # The effective level for a user. Public universes give every signed-in user
  # write access; private universes use the explicit membership level. The
  # owner is always an admin, even when no membership row exists.
  #
  # Nothing is remembered here: this method reads the membership table every time
  # it is called, because a caller may change a membership and ask again in the
  # same breath, and a remembered answer would outlive the write that made it
  # wrong. The place that answers the same question many times in one render is
  # `ApplicationHelper`, whose memo is discarded with the view.
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

    def queue_search_reindex
      Search::ReindexUniverseJob.perform_later(id)
    end
end
