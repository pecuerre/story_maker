# An explicit statement that an Item appears in a Scene, optionally with the
# author's own free-text role such as "carries", "on the table", or "destroyed".
# The role is an annotation, never a controlled vocabulary the application
# interprets, and a blank role simply means no role.
#
# An Item is a shared universe record: it is linked, never copied, so the same
# Item can appear in any number of Scenes across any number of Stories in the
# Universe. This is a join model rather than a plain HABTM association precisely
# because the role is part of the decision, and it carries no second derived
# source the way a Character's Dialogue speaker link does.
class SceneItem < ApplicationRecord
  include SoftDeletable

  belongs_to :scene
  belongs_to :item

  validates :item_id, uniqueness: { scope: :scene_id, conditions: -> { where(deleted_at: nil) },
    message: "is already in this scene" }
  validate :item_belongs_to_the_scene_universe

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
    # A presence link may only point at an Item of the Scene's own Universe.
    # SQLite foreign keys cannot prove the shared scope, so it is an
    # application-level rule like every other Scene world link.
    def item_belongs_to_the_scene_universe
      universe_id = scene_universe_id
      return if universe_id.blank? || item.nil?
      return if item.universe_id == universe_id

      errors.add(:item, "must belong to the scene's universe")
    end
end
