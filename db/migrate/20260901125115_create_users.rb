class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :users, :email_address, unique: true
    add_index :users, :slug, unique: true
  end
end
