# A universe's collaboration mode decides how a change reaches a record.
#
# `direct` writes straight through. The other two remember the change for its
# author to apply instead. It is one value with three named states rather than a
# pair of booleans, and it is stored rather than derived, because it is a decision
# an owner or administrator makes about the whole universe and every reader of a
# request has to be able to see the same answer.
#
# NOT NULL with a default: a universe that existed before this column was added
# has to answer the question too, and a mode-less universe is not a state the
# application can act on. The default is `direct`, which is what every universe
# did before the column existed, so adding it changes no universe's behaviour.
#
# The mode's meaning and what the three values commit the application to are
# decided in `docs/adr/0019-collaboration-foundations.md`.
class AddCollaborationModeToUniverses < ActiveRecord::Migration[8.1]
  def change
    add_column :universes, :collaboration_mode, :string, default: "direct", null: false
  end
end
