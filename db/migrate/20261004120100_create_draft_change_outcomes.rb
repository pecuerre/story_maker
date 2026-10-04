# What one remembered change's application did.
#
# This table is the stored half of finding 64: the apply decided, per change,
# whether it was written, why it was not, and what the author chose where a
# conflict was answered, and this is where that decision is kept afterwards. It is
# a **new row per change** rather than columns on `draft_changes`, because a
# remembered change is append-only (ADR 0019) — what a change *said* is a statement
# about one moment and nothing rewrites it — and because ADR 0021 rejected adding
# an outcome column to the change for the same reason.
#
# `state` is the applier's own vocabulary: `written`, or one of
# `DraftApplier::SKIP_REASONS`. `answer` is the author's choice for a change that
# was in conflict, one of `DraftApplier::ANSWERS`, and nil for a change nobody had
# to decide about. The two are separate columns because a change answered "mine"
# **is** written and a change answered "theirs" is not, so folding the answer into
# the state would make the state answer two questions at once.
#
# `draft_id` is redundant — the change knows its draft — and it is stored anyway
# for the two queries that need it without the join: the dependent destroy on
# `Draft`, and the drafts list's tally. `DraftChangeOutcome` validates the two
# agree rather than trusting either, the same way `DraftChange` validates the
# universe of the record it names.
#
# The unique index on `draft_change_id` is the rule "one outcome per change". A
# draft closes on its first apply (ADR 0021), so a change can only ever be applied
# once, and the index is what makes a second run that wrote a second row an error
# rather than a history that reads as two applies.
#
# There is `created_at` and no `updated_at`, for `draft_changes`' reason: what a run
# decided about one change is a statement about one moment.
class CreateDraftChangeOutcomes < ActiveRecord::Migration[8.1]
  def change
    create_table :draft_change_outcomes do |t|
      t.references :draft, null: false, foreign_key: true
      t.references :draft_change, null: false, foreign_key: true, index: { unique: true }
      t.string :state, null: false
      t.string :answer
      t.datetime :created_at, null: false
    end
  end
end
