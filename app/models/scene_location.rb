# An explicit statement that a Location is part of a Scene, optionally with the
# author's own free-text role such as "setting", "arrives at", or "left behind".
# The role is an annotation, never a controlled vocabulary the application
# interprets, and a blank role simply means no role.
#
# A Location is a shared universe record with its own hierarchy: it is linked,
# never copied, and linking it here says nothing about which nested place inside
# it a Scene used — that remains the author's own free-text role.
class SceneLocation < ApplicationRecord
  include SoftDeletable
  include HasDiscussion

  belongs_to :scene
  belongs_to :location

  validates :location_id, uniqueness: { scope: :scene_id, conditions: -> { where(deleted_at: nil) },
    message: ->(_record, _data) { I18n.t("scenes.participation_errors.already_in_scene") } }
  validate :location_belongs_to_the_scene_universe

  def universe
    scene&.universe
  end

# Not searchable: a presence link is a statement inside its Scene rather than a
# page of its own. `search_url` is nevertheless the one answer to "where is this
# record read", so it answers with the Scene page — which is exactly where this
# link is shown and where its own workspace lives.
def search_url
  Rails.application.routes.url_helpers.universe_story_scene_path(
    universe_slug: scene.universe.to_param, story_id: scene.story_id, id: scene_id
  )
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
    # A presence link may only point at a Location of the Scene's own Universe.
    # SQLite foreign keys cannot prove the shared scope, so it is an
    # application-level rule like every other Scene world link.
    def location_belongs_to_the_scene_universe
      universe_id = scene_universe_id
      return if universe_id.blank? || location.nil?
      return if location.universe_id == universe_id

      errors.add(:location, I18n.t("scenes.participation_errors.must_belong_to_scene_universe"))
    end
end
