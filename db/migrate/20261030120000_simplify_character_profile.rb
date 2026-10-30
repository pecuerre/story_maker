# A Character keeps only the fields a reader needs at a glance: name, tags,
# factions, pronouns, aliases, and a short summary. The structured profile
# answers (`wants`, `needs`, `lies_to_self`, `contradictions`,
# `under_pressure_they`, `never`) and the separate knowledge records are folded
# into one Markdown `description`, which carries its own `##` sections.
#
# Schema-only, as ADR 0003 requires: the disposable development data in
# `db/data/` is where the demo prose is reloaded from.
class SimplifyCharacterProfile < ActiveRecord::Migration[8.1]
  def change
    rename_column :characters, :at_a_glance, :summary
    add_column :characters, :description, :text

    remove_column :characters, :wants, :text
    remove_column :characters, :needs, :text
    remove_column :characters, :lies_to_self, :text
    remove_column :characters, :contradictions, :text
    remove_column :characters, :under_pressure_they, :text
    remove_column :characters, :never, :text

    drop_table :character_knowledges
  end
end
