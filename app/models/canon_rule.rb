# A rule the story must obey, such as what magic costs or how long a road takes.
#
# **A rule belongs to the Universe unless a Story owns it.** `story_id` is nullable
# on purpose: no story means the whole universe follows the rule, a story means
# only that story does. One table carries both because a rule is one record with
# one statement and one optional source passage either way; splitting universe
# rules from story rules would duplicate the wall, the editor, and the search
# document. The domain decision is in ADR 0039.
#
# **The record has its own name and slug.** The name is the short title a list,
# a search result, and a citation show; the statement stays the sentence the
# prose must obey. The slug is how the rule is addressed, because the
# story-interchange ledger already keys each item by a stable id (`K16`, `L2`,
# `D8`) and re-importing a source must find the same rule again. The slug is the
# ledger id when a rule comes from a source and the name parameterized otherwise.
# A rename must not re-address the rule, which is why this model does not include
# HasSlug — that concern regenerates the slug whenever the name changes. ADR 0045
# records why this reverses ADR 0039's addressed-by-id choice.
#
# The optional **category** is the source area the rule came from (the area
# file's name), and the optional **canon type** is the ledger's own distinction
# between a locked fact, a rule of the mechanism, a derived consequence, and an
# open question. The prefix in the source decides the type, so the attribute is
# stored rather than derived from the id at read time.
#
# Nothing here checks prose against a rule. A rule earns its keep beside the
# continuity findings inbox and the contradiction analyzer; this record is what
# those surfaces will read, not a checker of its own.
class CanonRule < ApplicationRecord
  include SoftDeletable
  include InvalidatesMenuCounts
  include InvalidatesUniverseSummary
  include Searchable
  include HasDiscussion

  # The ledger's four kinds of canon item, in the order the interface lists them.
  # A rule may carry none, because a rule written straight into the app need not
  # come from a ledger.
  CANON_TYPES = %w[ locked rule consequence open ].freeze

  searchable kind: "canon_rule", title: :name, body: :search_body, route: "canon_rule"
  invalidates_menu_counts_for :universe

  belongs_to :universe
  belongs_to :story, optional: true

  # Registered before the validations so a form that submits a blank slug still
  # saves with one derived from the name. It runs on every validation but keeps a
  # slug that already exists, so a ledger id survives the rule being renamed.
  before_validation :assign_slug

  validates :name, presence: true
  validates :slug, presence: true,
    uniqueness: { scope: :universe_id, conditions: -> { where(deleted_at: nil) } }
  validates :canon_type, inclusion: { in: CANON_TYPES }, allow_blank: true
  validates :statement, presence: true
  # A `story_id` that names nothing is a field error rather than the foreign key's
  # 500, for the same reason Scene's optional references are: the same id can
  # arrive from a form, the development-data loader, or a console, and only the
  # model covers all three.
  validate :story_reference_exists
  validate :story_belongs_to_universe

  # Whether this rule is the whole universe's rather than one story's.
  def universe_wide?
    story_id.nil?
  end

  # The name is the record's own label. The statement is the fallback for a row
  # written before names existed, which the next import replaces rather than the
  # application repairing in place.
  def display_string
    name.presence || statement
  end

  # The statement and the passage are both prose a reader searches by, so one
  # body carries them; the name alone would leave the rule itself unfindable.
  def search_body
    [ statement, source ].compact_blank.join(" ")
  end

  private

    # The slug a reader may type is normalized the same way every other slug in
    # the application is; when none is given, the name supplies one. `L2` becomes
    # `l2`, because a slug is lowercase and hyphenated everywhere else.
    def assign_slug
      self.slug = slug.presence&.parameterize
      self.slug = name.to_s.parameterize if slug.blank? && name.present?
    end

    def story_reference_exists
      errors.add(:story, I18n.t("shared.errors.reference.must_exist")) if story_id.present? && story.nil?
    end

    def story_belongs_to_universe
      return if story.nil? || universe.nil?
      return if story.universe_id == universe_id

      errors.add(:story, I18n.t("shared.errors.same_scope.universe"))
    end
end
