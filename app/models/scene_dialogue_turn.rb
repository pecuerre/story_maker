# One spoken line inside a Dialogue Scene Element: who speaks, the line itself,
# and an optional parenthetical delivery note, in a flat contiguous position
# inside its own Element.
#
# A turn is a component of its Element: it has no URL of its own and is created,
# moved, and deleted through the Element's editor on Scene Details. Its Universe
# is reached through `scene_element -> scene -> story -> universe`, so it declares
# no `universe_id` of its own.
#
# A turn's speaker is a same-Universe Character, or absent when the source names
# a speaker with no Character record. Such a turn is a **non-character speaker**:
# the line itself carries the speaker tag (`review-chair: …`), so the picker's
# `NON_CHARACTER_SPEAKER` value is a UI control rather than a stored speaker. The
# speaker is independent of the Element's block-level speaker roster. Speaking in
# a dialogue is not a Scene presence link: the turn says who speaks a line, not
# that the speaker takes part in the Scene, and it never stamps a SceneCharacter
# row.
class SceneDialogueTurn < ApplicationRecord
  include OrderedSequence
  include WordCountable

  # The speaker picker's value for a line whose speaker has no Character record.
  # It is never written to `speaker_id`; the controller turns it into nil.
  NON_CHARACTER_SPEAKER = "non_character".freeze

  # A turn's line is prose like an Element's Content, so it contributes to the
  # same Story and Section totals.
  counts_words_from :body

  ordered_sequence_within :scene_element

  belongs_to :scene_element, inverse_of: :scene_dialogue_turns
  belongs_to :speaker, class_name: "Character", optional: true, inverse_of: :scene_dialogue_turns_as_speaker

  delegate :scene, to: :scene_element, allow_nil: true
  delegate :story, to: :scene_element, allow_nil: true

  validate :speaker_must_be_known
  validate :speaker_belongs_to_scene_universe
  validate :body_present_for_non_character_speaker
  validate :element_is_dialogue

  def universe
    scene_element&.universe
  end

  # A speaker the source named as a bare `@slug`, or the picker's
  # "Non-character speaker", stores no Character. Its line carries the tag.
  def non_character_speaker?
    speaker_id.nil?
  end

  private

    # A null speaker is the supported non-character case, but a `speaker_id` that
    # does not resolve is still refused before the foreign key is reached.
    def speaker_must_be_known
      return if speaker_id.nil? || speaker.present?

      errors.add(:speaker, :required)
    end

    def speaker_belongs_to_scene_universe
      return if speaker.nil? || scene.nil? || scene.universe.nil?
      return if speaker.universe_id == scene.universe.id

      errors.add(:speaker, I18n.t("scenes.participation_errors.must_belong_to_scene_universe"))
    end

    # With no Character to name the speaker, the line itself must carry the tag.
    def body_present_for_non_character_speaker
      return unless non_character_speaker?
      return if body.present?

      errors.add(:body, :blank)
    end

    def element_is_dialogue
      return if scene_element.nil? || scene_element.dialogue?

      errors.add(:base, I18n.t("scenes.dialogue_turns.element_must_be_dialogue"))
    end
end
