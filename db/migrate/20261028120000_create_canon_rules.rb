class CreateCanonRules < ActiveRecord::Migration[8.1]
  def change
    create_table :canon_rules do |t|
      t.references :universe, null: false, foreign_key: true
      # A rule with no story is universe-wide; a rule naming one belongs to that
      # story. The column is nullable for that reason, not because ownership is
      # optional to record.
      t.references :story, foreign_key: true
      t.text :statement, null: false
      t.text :source
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :canon_rules, :deleted_at
    add_index :canon_rules, [ :universe_id, :id ]
    add_index :canon_rules, [ :story_id, :deleted_at ]
  end
end
