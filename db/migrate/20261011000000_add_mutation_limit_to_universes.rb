class AddMutationLimitToUniverses < ActiveRecord::Migration[8.1]
  def change
    # Schema-only, so the default is written as the literal rather than read from
    # the model: a migration that names an application constant stops working the
    # day that constant is renamed. The number is 60, and
    # `Universe::DEFAULT_MUTATION_LIMIT` is where it lives at runtime.
    #
    # Nullable on purpose. `60` is what every row gets, so a universe is
    # protected from the moment it exists rather than from the moment somebody
    # visits a settings page; `NULL` is then the one value an admin can store to
    # mean "no limit at all", which a plain positive-integer column has no way to
    # say and `0` would say wrongly — zero mutations is a closed universe, not an
    # unlimited one, and `private` is what expresses that.
    add_column :universes, :mutation_limit, :integer, default: 60, null: true
  end
end
