# The changes remembered inside one draft.
#
# `record_type` is a polymorphic reference and gets **no** foreign key: a
# database constraint cannot name a table that varies per row. It is registry
# gated by `RecordTarget` in the model instead, which matches the type against
# `Ability::CONTENT_CLASS_NAMES` before constantizing it, so a stored
# `record_type` can never become a loadable-constant injection and a draft can
# only ever remember a change to universe content.
#
# `record_id` is nullable because a `create` remembers a record that does not
# exist yet — the id is the database's to assign when the change is applied — and
# the other two actions remember one that is already there. `action` is therefore
# what decides which of the two shapes is coherent, and the model refuses the
# other rather than storing a row that says a not-yet-created record was
# updated, or that an existing one has no version.
#
# `base_version` is the version the record was last seen at, and it is a string
# because it is written into a row and compared days later. Every value written
# here goes through `VersionStamp`, which normalizes both sides: a stored `Time`
# is never equal to the string it is compared against, so a raw `updated_at`
# would report a conflict on *every* change and make conflict resolution useless
# rather than merely imperfect (ADR 0019).
#
# `payload` is the remembered attributes. It is **not** called `changes`, which
# is what the collaboration plan named it: Rails 8.1 refuses an attribute that
# Active Record already defines, and `changes` is `ActiveModel::Dirty`'s
# (`ActiveRecord::DangerousAttributeError`). `attributes` is refused the same
# way, so the payload keeps the name item 24.1 already uses for opaque stored
# data in this feature family.
#
# A change has `created_at` and **no** `updated_at`. What a change remembers is a
# statement about one moment — these attributes, this version — and an editable
# timestamp would let that statement drift away from what was actually observed.
# The composite index is the one query a draft makes: its changes in the order
# they were written, with `id` as the tiebreaker for two written inside one
# clock tick.
class CreateDraftChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :draft_changes do |t|
      t.references :draft, null: false, foreign_key: true
      t.string :record_type, null: false
      t.integer :record_id
      t.string :action, null: false
      t.json :payload
      t.string :base_version
      t.datetime :created_at, null: false
    end

    add_index :draft_changes, [ :draft_id, :created_at, :id ]
  end
end
