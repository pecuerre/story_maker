# An Item keeps only the fields a reader needs at a glance: name, description,
# tags, and its place in the hierarchy. The nine structured profile answers
# (what it does, how it is used, side effects, origin, value, cannot, constraints,
# history, and jargon) are folded into one Markdown `description`, which carries
# its own `##` sections.
#
# Schema-only, as ADR 0003 requires: the disposable development data in
# `db/data/` is where the demo prose is reloaded from.
class SimplifyItemProfile < ActiveRecord::Migration[8.1]
  def change
    remove_column :items, :what_it_does, :text
    remove_column :items, :how_it_is_used, :text
    remove_column :items, :side_effects, :text
    remove_column :items, :origin, :text
    remove_column :items, :value, :text
    remove_column :items, :cannot, :text
    remove_column :items, :constraints, :text
    remove_column :items, :history, :text
    remove_column :items, :jargon, :text
  end
end
