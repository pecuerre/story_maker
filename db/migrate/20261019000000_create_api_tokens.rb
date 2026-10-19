class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      # The bearer credential is shown once and never stored; only its digest is,
      # the same discipline as `password_digest`.
      t.string :token_digest, null: false
      # Enough leading characters of the bearer token to look the row up; the
      # prefix alone is not a credential.
      t.string :token_prefix, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :api_tokens, :token_prefix, unique: true
    add_index :api_tokens, :revoked_at
  end
end
