# One conversation per record.
#
# `record_type`/`record_id` is a polymorphic reference and gets no foreign key:
# a database constraint cannot name a table that varies per row. It is resolved
# and gated by `RecordTarget` in the model instead, which matches the type
# against `Ability::CONTENT_CLASS_NAMES` before constantizing it and requires the
# record to resolve to the universe this row names.
#
# `universe_id` *is* a real foreign key, and it is deliberately redundant with
# the reference. A thread has to be listed and authorized inside one universe
# whatever record it hangs on, and two independent columns are what makes a
# disagreement between them detectable: a foreign key alone would happily store a
# thread under a universe its record does not belong to.
#
# `title` is nullable and nothing writes it yet. There is one thread per record
# and the record is the thread's subject, so a title has nothing to name until
# the conversation page says what it is for; it is added here because the
# collaboration plan reserves it, not because this slice needs it.
#
# The unique pair index is what makes `has_one` true rather than merely
# intended: two find-or-create requests for one record must not leave two
# threads behind. It is also the same shape as the `Scene`'s own unique pairs, so
# this table follows the newer integrity convention rather than the legacy HABTM
# tables that have no constraints at all.
class CreateDiscussions < ActiveRecord::Migration[8.1]
  def change
    create_table :discussions do |t|
      t.references :universe, null: false, foreign_key: true
      t.string :record_type, null: false
      t.integer :record_id, null: false
      t.string :title

      t.timestamps
    end

    add_index :discussions, [ :record_type, :record_id ], unique: true
  end
end
