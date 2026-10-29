class AddIdentityToCanonRules < ActiveRecord::Migration[8.1]
  # The four columns are nullable in the table and required by the model. The
  # existing rows are deliberately not backfilled: the real rules arrive again
  # from the story-interchange source, so a migration that invented a slug from
  # today's statement would only be undone by the re-import. SQLite cannot add a
  # NOT NULL column without a default, and a blank default would collide under
  # the unique index below, so the model is the one place that enforces presence.
  def change
    add_column :canon_rules, :slug, :string
    add_column :canon_rules, :name, :string
    add_column :canon_rules, :category, :string
    add_column :canon_rules, :canon_type, :string

    # A slug is unique inside its Universe among live rules, the same partial
    # index every other soft-deletable record uses, so a re-import can reuse a
    # ledger id after the previous rows were soft-deleted.
    add_index :canon_rules, [ :universe_id, :slug ], unique: true,
      where: "deleted_at IS NULL", name: "index_canon_rules_on_live_universe_and_slug"
  end
end
