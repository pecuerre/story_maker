# Item 39: the single Scene-to-Event reference leaves the Scene row.
#
# `scenes.event_id` was the one Event a Scene could depict. The links now live in
# `scene_events`, where a Scene can have several, each with a role and an order.
# This migration is schema-only by ADR 0003: the disposable development data in
# `db/data/` is the source the links are reloaded from, not a data migration.
class RemoveEventFromScenes < ActiveRecord::Migration[8.1]
  def change
    remove_reference :scenes, :event, foreign_key: true
  end
end
