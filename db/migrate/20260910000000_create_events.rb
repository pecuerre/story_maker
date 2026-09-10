class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :title
      t.datetime :start_datetime
      t.datetime :end_datetime
      t.references :before_event, null: true, foreign_key: { to_table: :events }
      t.references :after_event, null: true, foreign_key: { to_table: :events }
      t.references :simultaneous_event, null: true, foreign_key: { to_table: :events }
      t.references :parent, null: true, foreign_key: { to_table: :events }
      t.references :story, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.text :description

      t.timestamps
    end
  end
end
