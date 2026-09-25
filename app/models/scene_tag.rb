class SceneTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug

  belongs_to :story
  has_many_tagd :scene, scope: :story_id

  validates :name, presence: true
  validate :scene_assignments_are_valid

  # Keep inverse assignment errors in the model as well. The Scene form is the
  # primary writer, but direct association/import callers must not turn an
  # unknown or foreign Scene id into a database exception.
  def scene_ids=(ids)
    requested_ids = Array(ids).filter_map { |id| id.respond_to?(:id) ? id.id : id }
      .compact_blank.map(&:to_s)
    normalized_ids = requested_ids.uniq
    existing_ids = Scene.where(id: requested_ids).pluck(:id).map(&:to_s)
    scope_story_id = story_id || story&.id
    scoped_ids = if scope_story_id.present?
      Scene.where(id: requested_ids, story_id: scope_story_id).pluck(:id).map(&:to_s)
    else
      # Defer the owner check for a record built through the inverse Story
      # association, where story_id is assigned after mass assignment.
      existing_ids
    end

    @scene_assignment_errors = []
    @scene_assignment_errors << "must exist" if (requested_ids - existing_ids).any?
    @scene_assignment_errors << "must belong to the same story" if (existing_ids - scoped_ids).any?
    @scene_assignment_errors << "must be unique" if normalized_ids.length != requested_ids.length

    self.scenes = Scene.where(id: scoped_ids).to_a
  end

  # Scene tags are scoped to their story instead of directly to the universe.
  private

    def scene_assignments_are_valid
      Array(@scene_assignment_errors).each do |message|
        errors.add(:scenes, message)
      end
    end

    def hierarchy_scope
    story
  end

  def hierarchy_scope_attribute
    :story_id
  end

  def hierarchy_scope_error
    "must belong to the same story"
  end
end
