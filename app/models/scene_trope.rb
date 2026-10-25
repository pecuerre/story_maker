# A Scene-level detection or deliberate annotation of one trope from the shared
# reference catalogue. The same trope may have a different context in each use.
#
# It is its own record rather than a checkbox on the Scene form because the
# Scene's Tropes tab lists the annotations the Scene carries and offers the
# catalogue through a picker. The catalogue itself is code-owned, so this row
# stores only the stable slug and the author's context note.
class SceneTrope < ApplicationRecord
  belongs_to :scene

  attr_writer :selected

  validates :trope_slug, presence: true, inclusion: { in: TropeCatalog.slugs, allow_blank: true }
  validates :trope_slug, uniqueness: { scope: :scene_id }
  validates :context_note, length: { maximum: 2000 }

  def selected
    return ActiveModel::Type::Boolean.new.cast(@selected) unless @selected.nil?

    persisted?
  end

  def trope
    TropeCatalog.find(trope_slug)
  end

  # Blank input means no note, not an empty-string note that reads as an
  # intentional value later. Normalizing here makes the live path, a remembered
  # change applied later, and a nested writer all store the same value.
  def context_note=(value)
    super(value.is_a?(String) ? value.strip.presence : value)
  end

  # A Scene has no `universe_id` of its own: it reaches its Universe through the
  # Story that owns it, so the shared scope is read from there.
  def universe
    scene&.universe
  end

  # Not searchable: an annotation is a statement inside its Scene rather than a
  # page of its own. `search_url` is nevertheless the one answer to "where is
  # this record read", so it answers with the Scene's Tropes tab — exactly where
  # this assignment is listed and edited.
  def search_url
    Rails.application.routes.url_helpers.universe_story_scene_scene_tropes_path(
      universe_slug: scene.universe.to_param, story_id: scene.story_id, scene_id: scene_id
    )
  end

  # What a draft row calls this assignment. The catalogue name is the record's
  # own name; the stored slug is the fallback for a payload that names a
  # reference the catalogue no longer holds.
  def display_label
    trope&.name || trope_slug
  end
end
