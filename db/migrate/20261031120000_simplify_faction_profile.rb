# A Faction keeps only the fields a reader needs at a glance: name, tags, and a
# short summary. The seven structured profile answers are folded into one
# Markdown `description`, which carries its own `##` sections.
#
# Schema-only, as ADR 0003 requires: the disposable development data in
# `db/data/` is where the demo prose is reloaded from.
class SimplifyFactionProfile < ActiveRecord::Migration[8.1]
  def change
    add_column :factions, :summary, :text
    add_column :factions, :description, :text

    remove_column :factions, :mission, :text
    remove_column :factions, :actual_aims, :text
    remove_column :factions, :structure, :text
    remove_column :factions, :internal_divisions, :text
    remove_column :factions, :resources, :text
    remove_column :factions, :would_never, :text
    remove_column :factions, :would_absolutely, :text
  end
end
