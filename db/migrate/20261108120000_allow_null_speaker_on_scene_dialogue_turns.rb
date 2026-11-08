# A Dialogue turn may name a speaker with no Character record: a bare `@slug`
# speaker from the interchange, or the editor's "Non-character speaker" choice.
# The line then carries the speaker tag itself, so the Character link is absent
# rather than pointing at a placeholder the Universe would have to hold.
class AllowNullSpeakerOnSceneDialogueTurns < ActiveRecord::Migration[8.1]
  def change
    change_column_null :scene_dialogue_turns, :speaker_id, true
  end
end
