class Universe < ApplicationRecord
  MENU_COUNT_ASSOCIATIONS = %i[characters relations locations events items ownerships].freeze

  # The one value that decides how a change reaches a record in this universe:
  # `direct` writes straight through, while the other two remember the change for
  # its author to apply instead. The stored string is not the interface — read the
  # mode through the predicates below, so a new value cannot arrive with callers
  # still comparing the string themselves and answering "not direct" without
  # saying what it is.
  COLLABORATION_MODES = %w[direct wikipedia github].freeze

  # How many mutations one account may make in this universe per minute when the
  # admin has not configured a number of their own.
  #
  # Sixty is one a second, sustained, and that is chosen against what this
  # application actually does rather than against a guess: there is no bulk or
  # batch path anywhere in it, so every mutation is one deliberate act (a modal
  # submit, one taxonomy edit, one scene drag) and a person cannot reach this
  # through ordinary work. A script can, in about a second.
  DEFAULT_MUTATION_LIMIT = 60

  # The window `mutation_limit` is counted in. It is a constant rather than a
  # column because a window is not the thing an admin has an opinion about — the
  # budget is. A per-universe rate is "N per minute" wherever N comes from.
  MUTATION_LIMIT_WINDOW = 1.minute

  # The per-group ceilings, as `group => the column that holds it`.
  #
  # One bucket for every mutation is a blunt instrument: a burst of photo uploads
  # and a burst of scene edits spent the same budget, so either could starve the
  # other without either being what the budget was for. Each group below is a
  # **sub-limit inside** `mutation_limit` — a grouped mutation spends both, and is
  # refused if either is over — so the admin's overall budget stays the bound on
  # total writes and the group's number is what binds first inside it. ADR 0029 is
  # the decision; `MutationThrottle` is the only reader.
  #
  # The map is here rather than in the controller because these are columns, and the
  # model that owns a column is where its rules live: the defaults, the validation,
  # the `NULL` reading, and the name each group is stored under are all answered
  # from one place, so a fourth group is one entry here plus its column.
  MUTATION_GROUP_COLUMNS = {
    photo: :photo_mutation_limit,
    membership: :membership_mutation_limit,
    discussion: :discussion_mutation_limit
  }.freeze

  # What each group falls back to when its column stores neither a number nor a
  # `NULL` — an incomplete row: a fixture written before the column existed, a
  # default that was dropped. It is the same reasoning as `mutation_limit` below; a
  # row carrying neither value must never be the one unprotected state.
  MUTATION_GROUP_LIMITS = {
    photo: 10,
    membership: 10,
    discussion: 30
  }.freeze

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
  # The column's default is 60, which is also `DEFAULT_MUTATION_LIMIT`, so a
  # universe is never left unprotected because nobody opened a settings page.
  #
  # `NULL` is the stored form of "no limit" — the one value an admin can choose
  # that is not a number of requests — and zero is refused rather than stored,
  # because zero mutations and no limit are different settings and only one of
  # them is what anybody means by the field. A universe nobody may write to is
  # private and read-only, which `private` and the membership levels already say.
  validates :mutation_limit, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  # The same rule, validation included, for every per-group ceiling: `NULL` is "no
  # limit on this group", `0` is refused, and a fractional number is refused.
  # `MUTATION_GROUP_COLUMNS` is the list, so a fourth group cannot arrive with a
  # column and no rule.
  validates(*MUTATION_GROUP_COLUMNS.values,
    numericality: { only_integer: true, greater_than: 0 }, allow_nil: true)
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
  # A token grant names this universe, so it goes with the universe. `delete_all`
  # because the join table has no primary key of its own.
  has_many :api_token_universes, dependent: :delete_all
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

  # How many mutations one account may make here per `MUTATION_LIMIT_WINDOW`.
  # `nil` means no limit, which is the stored `NULL` rather than a number too
  # large to reach — the reader of the column can tell "unlimited" from "a lot"
  # without being told, and the third slice has a real value to compare a
  # per-endpoint group against.
  #
  # A row that somehow carries neither (a default that was dropped, a fixture
  # written before the column existed) answers the same as a configured one:
  # the default. Falling back to *no* limit instead would make an incomplete row
  # the one state that is unprotected.
  def mutation_limit
    self[:mutation_limit] || DEFAULT_MUTATION_LIMIT
  end

  def mutations_unlimited?
    self[:mutation_limit].nil?
  end

  # How many mutations of one group one account may make here per
  # `MUTATION_LIMIT_WINDOW`. `nil` is not the answer to this question — it is
  # `mutation_group_unlimited?`'s — so what a `NULL` column yields here is the
  # default, and the throttle asks the other question first.
  def mutation_group_limit(group)
    self[MUTATION_GROUP_COLUMNS.fetch(group)] || MUTATION_GROUP_LIMITS.fetch(group)
  end

  # Whether this group alone has no limit, which is deliberately a different answer
  # from `mutations_unlimited?`: an admin can leave a universe's content budget
  # open while keeping a ceiling on what one account may upload or grant.
  def mutation_group_unlimited?(group)
    self[MUTATION_GROUP_COLUMNS.fetch(group)].nil?
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

  # Everybody who collaborates in this universe: its owner plus its members.
  #
  # **It is a method rather than `has_many :members, through: :memberships` because
  # the owner is not a membership row.** `UniverseMembership` refuses to record one
  # (`user_is_not_universe_owner`), so the association answers "the people I invited"
  # and leaves out the person who founded the universe — the one collaborator every
  # universe has and the one most likely to be dropped from a list of members. An
  # ordinary reader asking "who is in this universe with me?" has no way to know that
  # half the answer has no row, so the union is done once here.
  #
  # `Universe#administrators` is the same union narrowed to `admin`, and
  # `User#universes` is this relation seen from the other end; all three name the
  # owner explicitly, which is what makes them agree.
  def members
    User.where(id: [ owner_id ] + memberships.pluck(:user_id))
  end

  # Everybody who administers this universe: its owner, plus the members whose level is
  # `admin`. It is the `administrated_by` scope read the other way round, and it is
  # what says who a submitted draft is handed over to — `admin` access is the whole of
  # `ReviewRequestsController`'s authorization, so this is exactly the set of people who
  # can open the queue a submission lands in, and nobody else can.
  #
  # A **public** universe does not widen it: `access_level_for` grants every signed-in
  # reader `write`, and `write` is not the queue's access level.
  #
  # The owner is listed alongside the memberships rather than through one, because the
  # owner is an admin with no membership row at all — `UniverseMembership` refuses to
  # record one — so a query built from `memberships` alone would leave out the one
  # person who administers every universe there is.
  def administrators
    User.where(id: [ owner_id ] + memberships.admin.pluck(:user_id))
  end

  alias_method :administered_by?, :administrable_by?

  def menu_counts
    MenuCountCache.fetch(MenuCountCache.key(:universe, id), connection: self.class.connection) do
      MENU_COUNT_ASSOCIATIONS.to_h do |association|
        [ association, public_send(association).count ]
      end
    end
  end

  # What the Universes index shows beside each universe: how much it holds and
  # when it was last touched. Cached like `menu_counts` so the list fills each
  # universe's figures once instead of once per row per render. `activity_at`
  # is the newest `updated_at` among everything counted, so recent activity
  # means a record was created, edited, or restored — not merely viewed.
  SUMMARY_COUNT_ASSOCIATIONS = %i[stories characters locations events items relations ownerships].freeze

  def summary_counts
    MenuCountCache.fetch(MenuCountCache.key(:universe_summary, id), connection: self.class.connection) do
      counts = SUMMARY_COUNT_ASSOCIATIONS.index_with { |association| public_send(association).count }

      activity_at = SUMMARY_COUNT_ASSOCIATIONS.map do |association|
        public_send(association).maximum(:updated_at)
      end.compact.max

      counts.merge(
        entities: counts.except(:stories).values.sum,
        activity_at: activity_at
      )
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
