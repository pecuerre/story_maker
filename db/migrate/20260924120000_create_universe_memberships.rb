class CreateUniverseMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :universe_memberships do |t|
      t.references :universe, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :access_level, null: false, default: 1

      t.timestamps
    end

    add_index :universe_memberships, [ :universe_id, :user_id ], unique: true
  end
end
