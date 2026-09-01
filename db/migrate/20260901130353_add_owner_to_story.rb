class AddOwnerToStory < ActiveRecord::Migration[8.1]
  def change
    add_reference :stories, :owner, null: false, foreign_key: { to_table: :users }
  end
end
