# Item 39: a Scene may depict several Events.
#
# A Scene's link to an Event is no longer a single column. Each row is one Event
# the Scene depicts, carrying the author's own free-text role and its order among
# that Scene's Events. The link is scene-owned, reaches its Universe through
# `scene -> story -> universe`, and soft-deletes so removing it keeps the row's
# history while freeing the pair for a later re-link.
class CreateSceneEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_events do |t|
      t.references :scene, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.string :role
      t.integer :position, null: false, default: 0
      t.datetime :deleted_at

      t.timestamps
    end

    # The order of a Scene's own Events, independent of the Scene's narrative
    # position and of the Event's place in the Timeline.
    add_index :scene_events, [ :scene_id, :position ]
    # One Event is linked to one Scene at most while the link is live. The partial
    # index is what lets a removed link be created again without resurrecting the
    # soft-deleted row.
    add_index :scene_events, [ :scene_id, :event_id ], unique: true, where: "deleted_at IS NULL"
    add_index :scene_events, :deleted_at
  end
end
