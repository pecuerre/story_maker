# A rule the story must obey, such as what magic costs or how long a road takes.
#
# **A rule belongs to the Universe unless a Story owns it.** `story_id` is nullable
# on purpose: no story means the whole universe follows the rule, a story means
# only that story does. One table carries both because a rule is one record with
# one statement and one optional source passage either way; splitting universe
# rules from story rules would duplicate the wall, the editor, and the search
# document. The domain decision is in ADR 0039.
#
# **The record is addressed by its id, not by a slug.** Unlike a Character or a
# Route, a Canon Rule has no name to derive one from: its identity is the
# statement, which is prose. Deriving a slug from it would re-address the rule
# every time an author rewords it, and a citation stored as a slug would then
# dangle. The stable id is what a `[[rule:ID]]` reference can point at, so a rule
# can be reworded without breaking the passage that cites it.
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

  searchable kind: "canon_rule", title: :statement, body: :source, route: "canon_rule"
  invalidates_menu_counts_for :universe

  belongs_to :universe
  belongs_to :story, optional: true

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

  # The statement is the record's own label: a rule has no separate name, and the
  # shared row partials name a record through this. It is author-written prose, so
  # it is never translated; only the chrome around it is.
  def display_string
    statement
  end

  private

    def story_reference_exists
      errors.add(:story, I18n.t("shared.errors.reference.must_exist")) if story_id.present? && story.nil?
    end

    def story_belongs_to_universe
      return if story.nil? || universe.nil?
      return if story.universe_id == universe_id

      errors.add(:story, I18n.t("shared.errors.same_scope.universe"))
    end
end
