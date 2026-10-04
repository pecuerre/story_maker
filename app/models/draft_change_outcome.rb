# What one remembered change's application did, kept after the run that decided it.
#
# This is the stored answer to a question a remembered change cannot answer about
# itself. `DraftChange` says what the author *asked for*; an outcome says what the
# universe did with it. Both are kept, because both are true: a draft's page still
# lists the values a change carried, and now also says whether that change became
# live.
#
# **A new row, not a column on `draft_changes`.** A remembered change is append-only
# (ADR 0019): what it said is a statement about one moment, and nothing rewrites
# it. An outcome is a statement about a *later* moment, so it is its own row rather
# than a mutable attribute — which is also what makes the unique index on
# `draft_change_id` the rule "one outcome per change" rather than a convention.
#
# **Two columns rather than one, because they answer two questions.** `state` is
# whether the change was written and, when it was not, why;
# `DraftApplier::SKIP_REASONS` is the vocabulary of that "why", and `written` is
# the one state that is not a reason. `answer` is what the author chose where a
# conflict was asked about, and it is separate because a change answered `"mine"`
# **is** written — its state is `written` — while one answered `"theirs"` is not
# written and its state is still the conflict that put it there. Folding the answer
# into the state would give one column two answers.
#
# `draft_id` is derivable from the change and is stored so the dependent destroy
# and the drafts list's tally need no join. It is checked against the change's own
# draft rather than trusted, which is the same disagreement `DraftChange` refuses
# between a draft's universe and the universe of the record it names.
#
# The row is append-only for `DraftChange`'s reason: a run's decision about one
# change is a statement about one moment, and an editable `state` would let the
# history drift away from what actually happened. An update **raises** rather than
# being ignored, for the same reason and with the same message shape.
class DraftChangeOutcome < ApplicationRecord
  # The one state that is not a reason: the change was written. It is named here
  # because the stored vocabulary is the union of this and the applier's six
  # reasons, and that union is what a row may hold.
  WRITTEN = "written"

  # The applier's own skip reasons, as the strings a column holds. They are read
  # from `DraftApplier` rather than listed here so there is one vocabulary for the
  # service that reports a reason, the model that stores it, and the view that
  # reads it — and `test/services/draft_applier_test.rb` fails when a reason is
  # added to the applier and not to `STATES`.
  SKIP_REASONS = DraftApplier::SKIP_REASONS.map(&:to_s).freeze

  STATES = [ WRITTEN, *SKIP_REASONS ].freeze

  belongs_to :draft
  belongs_to :draft_change

  validates :state, presence: true, inclusion: { in: STATES }
  # An answer only ever arrives for a change the conflict page asked about, and it
  # is the same two words `DraftApplier::ANSWERS` holds — the page's buttons, the
  # controller's params, and this column cannot each hold a vocabulary of their own.
  validates :answer, inclusion: { in: DraftApplier::ANSWERS }, allow_nil: true
  validate :belongs_to_the_same_draft_as_its_change

  before_update :refuse_to_be_rewritten

  # The three outcomes a draft's page draws, asked about by name rather than by
  # re-deriving them from two columns at each call site. `written?` and `kept?` are
  # `DraftApplier::Outcome`'s own two predicates: this row is what that object left
  # behind, so the two halves cannot answer differently.
  def written?
    state == WRITTEN
  end

  # A change the author answered `"theirs"`: the record keeps what is there and the
  # remembered change is dropped. It is not written, and it is not a failure, which
  # is why it is counted apart from the skipped ones on the draft's history.
  def kept?
    answer == "theirs"
  end

  # What was not written and not chosen away — the changes an apply reported rather
  # than wrote. It is the third count, and the only one that names a reason.
  def skipped?
    !written? && !kept?
  end

  private

    def refuse_to_be_rewritten
      raise ActiveRecord::ReadOnlyRecord, "an apply's outcome is append-only: #{self.class.name} #{id}"
    end

    def belongs_to_the_same_draft_as_its_change
      return if draft.nil? || draft_change.nil? || draft_change.draft.nil?
      return if draft_change.draft_id == draft_id

      errors.add(:draft, I18n.t("shared.errors.same_scope.draft"))
    end
end
