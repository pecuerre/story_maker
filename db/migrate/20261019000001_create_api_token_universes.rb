class CreateApiTokenUniverses < ActiveRecord::Migration[8.1]
  def change
    create_table :api_token_universes, id: false do |t|
      t.references :api_token, null: false, foreign_key: true
      t.references :universe, null: false, foreign_key: true
    end

    add_index :api_token_universes, %i[api_token_id universe_id], unique: true
  end
end
