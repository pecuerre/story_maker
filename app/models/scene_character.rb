# An explicit statement that a Character takes part in a Scene, optionally with
# the author's own free-text role such as "setting", "enters", or "objective".
# The role is an annotation, never a controlled vocabulary the application
# interprets, and a blank role simply means no role.
#
# This is a join model rather than a plain HABTM association precisely because
# the role is part of the decision. It is deliberately separate from the
# Dialogue speaker link: speaking makes a Character a participant of the Scene
# without creating a second stored row, so the same Character can be both an
# explicit participant and a speaker.
class SceneCharacter < ApplicationRecord
  belongs_to :scene
  belongs_to :character

  validates :character_id, uniqueness: { scope: :scene_id, message: "is already in this scene" }
  validate :character_belongs_to_the_scene_universe

  def universe
    scene&.universe
  end

  # Blank input means no role, not an empty-string role that reads as an
  # intentional value later.
  def role=(value)
    super(value.is_a?(String) ? value.strip.presence : value)
  end

  # `Scene` has no `universe_id` of its own: it reaches its Universe through the
  # Story that owns it, so the shared scope is read from there.
  def scene_universe_id
    scene&.universe&.id
  end

  private
    # A presence link may only point at a Character of the Scene's own Universe.
    # SQLite foreign keys cannot prove the shared scope, so it is an
    # application-level rule like every other Scene world link.
    def character_belongs_to_the_scene_universe
      universe_id = scene_universe_id
      return if universe_id.blank? || character.nil?
      return if character.universe_id == universe_id

      errors.add(:character, "must belong to the scene's universe")
    end
end
