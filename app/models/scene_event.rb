# One Event a Scene depicts, with the author's own free-text role and its order
# among that Scene's Events.
#
# This is a join model rather than a plain HABTM association because both the
# role and the order are part of the decision: the same Event can be told from a
# different angle in another Scene, and a Scene that depicts several Events needs
# a stable order in which they are listed. A blank role means no role, never a
# controlled vocabulary, and the row is independent of the Scene's own
# `datetime`: neither writes, clears, nor validates against the other.
#
# The link reaches its Universe through `scene -> story -> universe`, so it
# declares no `universe_id` of its own, and it soft-deletes with its Scene so a
# removed link can be re-created without resurrecting the old row.
class SceneEvent < ApplicationRecord
  include SoftDeletable
  include HasDiscussion
  include OrderedSequence

  ordered_sequence_within :scene

  belongs_to :scene
  # Required, but declared optional here so an unknown id is reported by the
  # ordinary validations below rather than by the generated presence validation
  # alone: the editor resolves an Event through the request's Universe (a 404),
  # while a console, the development-data loader, and a direct model write still
  # need a field error instead of a foreign-key exception.
  belongs_to :event, optional: true

  validates :event, presence: true, if: -> { event_id.blank? }
  validates :event_id, uniqueness: { scope: :scene_id, conditions: -> { where(deleted_at: nil) },
    message: ->(_record, _data) { I18n.t("scenes.events.already_linked") } }
  validate :event_reference_exists
  validate :event_belongs_to_the_scene_universe

  def universe
    scene&.universe
  end

  # A link has no name of its own: it is identified by the Event it depicts, in
  # the reader's language. This is also what a remembered change prints as its
  # subject on the drafts page.
  def display_label
    event&.display_label
  end

  # Not searchable: a depicted Event is a statement inside its Scene rather than
  # a page of its own. `search_url` is nevertheless the one answer to "where is
  # this record read", so it answers with the Scene's Events tab — exactly where
  # this link is listed and edited.
  def search_url
    Rails.application.routes.url_helpers.universe_story_scene_scene_events_path(
      universe_slug: scene.universe.to_param, story_id: scene.story_id, scene_id: scene_id
    )
  end

  # Blank input means no role, not an empty-string role that reads as an
  # intentional value later.
  def role=(value)
    super(value.is_a?(String) ? value.strip.presence : value)
  end

  def scene_universe_id
    scene&.story&.universe_id
  end

  private
    # An unknown optional id would otherwise raise a foreign-key exception (a
    # 500) instead of rendering a field error.
    def event_reference_exists
      errors.add(:event, I18n.t("scenes.errors.must_exist")) if event_id.present? && event.nil?
    end

    # A link may only point at an Event of the Scene's own Universe. SQLite
    # foreign keys cannot prove the shared scope, so it is an application-level
    # rule like every other Scene world link.
    def event_belongs_to_the_scene_universe
      return if event.nil? || scene_universe_id.blank?
      return if event.universe_id == scene_universe_id

      errors.add(:event, I18n.t("scenes.errors.must_belong_to_universe"))
    end
end
