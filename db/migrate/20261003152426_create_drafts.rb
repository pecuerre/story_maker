# One author's remembered changes for one universe.
#
# A draft is per author, not per universe: it is the working set of the person
# who is editing, and nobody else has a route to it. That is why `user_id` is
# part of the key rather than a detail of the row.
#
# `status` carries the column default *and* the model's `STATUSES` list, which
# are deliberately the same set. A status the application has no behaviour for
# would otherwise be a draft nothing can apply or discard, and the reader would
# find that out by watching a button do nothing.
#
# There is deliberately **no** unique index on `[user_id, universe_id]`. The
# collaboration plan's deferred decisions say one draft at a time per author per
# universe, but an applied draft stays behind as history, so the next editing
# session needs a new row; an index that forbade it would make a second session
# impossible. "One open draft" is an application rule of the editing flow, and
# the composite index below serves the query that list makes.
#
# Both foreign keys are real. A draft must belong to the person who wrote it and
# to the universe whose authorization it will be applied under, and neither
# column can be inferred from a row that is not there yet — a draft whose first
# change creates a record has no record to derive either half from.
class CreateDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :drafts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :universe, null: false, foreign_key: true
      t.string :status, null: false, default: "draft"

      t.timestamps
    end

    add_index :drafts, [ :user_id, :universe_id ]
  end
end
