class RequireUniversePrivateFlag < ActiveRecord::Migration[8.1]
  def change
    # Do not guess whether an existing NULL universe was public or private. The
    # migration fails until an operator resolves such rows explicitly.
    change_column_null :universes, :private, false
  end
end
