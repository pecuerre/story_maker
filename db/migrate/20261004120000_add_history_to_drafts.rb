# What a closed draft remembers about the run that closed it.
#
# Before these columns, an apply's outcome existed only in the flash that followed
# it: `DraftApplier::Result` said what was written and why the rest was not, and
# the controller turned that into one sentence that scrolled away. A draft's own
# page could not say which of its changes were written because an apply moves
# every version it writes, so a comparison cannot distinguish "written by this
# draft" from "changed by somebody else" (ADR 0021, finding 64).
#
# `closed_at` is one column rather than one per closing reason, because `status`
# already says **which** closure it was and this says **when**. It is written by
# whatever action closes the draft — the applier inside its own transaction, the
# discard action outside one — and the statuses it belongs to are the ones outside
# `OPEN_STATUSES`. A `submitted` draft is open (ADR 0019), so a review request in
# flight has no closure moment, which is what the word is for.
#
# The three counts are the run's tally, stored beside the moment rather than
# recomputed from the outcome rows: the drafts list prints them for every row on
# the page, and a list that had to group the outcome table first would be the one
# list in the application that resolves per row. `DraftApplier` writes them from
# the same `Result` that writes those rows, inside the same transaction, and
# `test/services/draft_applier_test.rb` asserts the columns against the rows so
# the two cannot drift.
#
# The statuses are written out rather than read from `Draft::OPEN_STATUSES` for
# the same reason the partial index spells its own list out: a migration is
# schema-only and has to keep saying what it said on the day it ran. The backfill
# reads a closed draft's `updated_at` as its moment, which is exact rather than
# approximate — a draft's row is written once and moved once, when it closes.
class AddHistoryToDrafts < ActiveRecord::Migration[8.1]
  def up
    add_column :drafts, :closed_at, :datetime
    add_column :drafts, :applied_count, :integer, null: false, default: 0
    add_column :drafts, :skipped_count, :integer, null: false, default: 0
    add_column :drafts, :kept_count, :integer, null: false, default: 0

    execute <<~SQL.squish
      UPDATE drafts SET closed_at = updated_at WHERE status IN ('applied', 'discarded')
    SQL
  end

  def down
    remove_column :drafts, :kept_count
    remove_column :drafts, :skipped_count
    remove_column :drafts, :applied_count
    remove_column :drafts, :closed_at
  end
end
