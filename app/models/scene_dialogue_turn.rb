# One spoken line inside a Dialogue Scene Element: who speaks, the line itself,
# and an optional parenthetical delivery note, in a flat contiguous position
# inside its own Element.
#
# A turn is a component of its Element: it has no URL of its own and is created,
# moved, and deleted through the Element's editor on Scene Details. Its Universe
# is reached through `scene_element -> scene -> story -> universe`, so it declares
# no `universe_id` of its own.
#
# A turn's speaker is a same-Universe Character and is independent of the
# Element's block-level speaker roster. Speaking in a dialogue is not a Scene
# presence link: the turn says who speaks a line, not that the speaker takes part
# in the Scene, and it never stamps a SceneCharacter row.
class SceneDialogueTurn < ApplicationRecord
  include OrderedSequence
  include WordCountable

  # A turn's line is prose like an Element's Content, so it contributes to the
  # same Story and Section totals.
  counts_words_from :body

  ordered_sequence_within :scene_element

  belongs_to :scene_element, inverse_of: :scene_dialogue_turns
  belongs_to :speaker, class_name: "Character", inverse_of: :scene_dialogue_turns_as_speaker

  delegate :scene, to: :scene_element, allow_nil: true
  delegate :story, to: :scene_element, allow_nil: true

  validates :speaker, presence: true
  validate :speaker_belongs_to_scene_universe
  validate :element_is_dialogue

  def universe
    scene_element&.universe
  end

  private

    def speaker_belongs_to_scene_universe
      return if speaker.nil? || scene.nil? || scene.universe.nil?
      return if speaker.universe_id == scene.universe.id

      errors.add(:speaker, I18n.t("scenes.participation_errors.must_belong_to_scene_universe"))
    end

    def element_is_dialogue
      return if scene_element.nil? || scene_element.dialogue?

      errors.add(:base, I18n.t("scenes.dialogue_turns.element_must_be_dialogue"))
    end
end
