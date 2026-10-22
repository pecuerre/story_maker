# A Scene may name one same-universe Character whose perspective presents it,
# separate from who takes part in the scene and from its linked event.
class AddPovCharacterToScenes < ActiveRecord::Migration[8.1]
  def change
    # `add_reference` adds the index itself in this Rails version, so declaring
    # one here would fail on every fresh database.
    add_reference :scenes, :pov_character, null: true, foreign_key: { to_table: :characters }
  end
end
