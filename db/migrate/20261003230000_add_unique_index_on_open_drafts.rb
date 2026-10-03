# One author cannot have two unfinished drafts in one universe.
#
# ADR 0019 deliberately left this index off: an applied draft stays behind as
# history, so a constraint across *every* status would make a second editing
# session impossible. The constraint is therefore **partial** — it covers the
# open statuses and nothing else, which is exactly the rule "one open draft per
# author per universe" — and the plain composite index stays, because the
# reader's draft list still needs the history rows too (ADR 0022).
#
# The statuses are written out rather than read from `Draft::OPEN_STATUSES`,
# because a migration is schema-only and has to keep saying what it said on the
# day it ran. The cost of that duplication is paid by
# `test/models/draft_test.rb`, which reads this index back out of the database
# and fails when the frozen list and the model's have drifted apart.
class AddUniqueIndexOnOpenDrafts < ActiveRecord::Migration[8.1]
  def change
    add_index :drafts, [ :user_id, :universe_id ],
      unique: true,
      where: "status IN ('draft', 'submitted')",
      name: "index_drafts_on_user_and_universe_while_open"
  end
end
