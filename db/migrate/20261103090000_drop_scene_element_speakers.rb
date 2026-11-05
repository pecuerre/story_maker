# A Dialogue's cast is its ordered turns now: every saved line already names a
# speaker, so the separate block-level speaker roster had no fact of its own and
# could disagree with the lines it was meant to describe. The join table carried
# no data and no order, so dropping it loses nothing the turns do not already
# say.
class DropSceneElementSpeakers < ActiveRecord::Migration[8.1]
  def change
    drop_table :scene_element_speakers
  end
end
