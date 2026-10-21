class AddMutationLimitToApiTokens < ActiveRecord::Migration[8.1]
  def change
    # Schema-only, so the default is the literal: a migration that names an
    # application constant stops working the day that constant is renamed.
    # `60` is what every token gets, so a credential is limited from the moment
    # it exists; `NULL` is then the one value that means "no limit at all" for a
    # token an operator has deliberately opened up, and `0` is refused because
    # zero mutations and no limit are different settings.
    add_column :api_tokens, :mutation_limit, :integer, default: 60, null: true
  end
end
