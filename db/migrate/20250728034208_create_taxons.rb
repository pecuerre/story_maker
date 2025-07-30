class CreateTaxons < ActiveRecord::Migration[8.0]
  def change
    create_table :taxons do |t|
      t.string :name
      t.references :taxonomy, null: false, foreign_key: true
      t.references :parent, null: true, foreign_key: { to_table: :taxons }

      t.timestamps
    end
  end
end
