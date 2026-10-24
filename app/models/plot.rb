# A Plot is a story-owned narrative through-line that can cross Sections and
# connect any number of Scenes. It is deliberately neither a Scene Tag nor a
# Section: it names a continuing arc, rather than classifying a Scene or
# organizing the Story's script hierarchy.
class Plot < ApplicationRecord
  include HasSlug
  include SoftDeletable
  include InvalidatesMenuCounts
  include Searchable
  include HasDiscussion

  searchable kind: "plot", title: :name, body: :description, route: "plot", scope: :story
  invalidates_menu_counts_for :story, cache_scope: Story::PLOT_MENU_COUNT_SCOPE

  belongs_to :story
  has_and_belongs_to_many :scenes,
    ->(plot) { where(story_id: plot.story_id) },
    join_table: :plots_scenes,
    foreign_key: :plot_id,
    association_foreign_key: :scene_id

  validates :name, presence: true,
    uniqueness: { scope: :story_id, conditions: -> { where(deleted_at: nil) } }
  validates :slug, uniqueness: { scope: :story_id, conditions: -> { where(deleted_at: nil) } }
  validate :scene_assignments_are_valid

  # One grouped query supplies the Scene count badge for every Plot row without
  # eager loading an instance-scoped HABTM association.
  def self.scene_counts_by_story(story)
    joins("INNER JOIN plots_scenes ON plots_scenes.plot_id = plots.id")
      .joins("INNER JOIN scenes ON scenes.id = plots_scenes.scene_id")
      .where(plots: { story_id: story.id }, scenes: { story_id: story.id, deleted_at: nil })
      .group("plots.id").count
  end

  # Keep the inverse side safe for both form and loader assignments. A Plot may
  # only name Scenes in its Story; invalid ids become model errors, not FK errors.
  def scene_ids=(ids)
    assign_scenes(Array(ids), ids: true)
  end

  def scenes=(records)
    assign_scenes(Array(records))
  end

  private
    def assign_scenes(records, ids: false)
      requested_ids = records.filter_map { |record| ids ? record : record&.id }
        .compact_blank.map(&:to_s)
      unique_ids = requested_ids.uniq
      existing = Scene.where(id: requested_ids).to_a
      existing_ids = existing.map { |scene| scene.id.to_s }
      scope_story_id = story_id || story&.id
      scoped = scope_story_id.present? ? existing.select { |scene| scene.story_id == scope_story_id } : []
      scoped_ids = scoped.map { |scene| scene.id.to_s }

      @scene_assignment_errors = []
      @scene_assignment_errors << I18n.t("plots.errors.scene_must_exist") if (requested_ids - existing_ids).any?
      @scene_assignment_errors << I18n.t("plots.errors.scene_must_belong_to_story") if (existing_ids - scoped_ids).any?
      @scene_assignment_errors << I18n.t("plots.errors.scene_must_be_unique") if unique_ids.length != requested_ids.length

      association(:scenes).writer(scoped)
    end

    def scene_assignments_are_valid
      Array(@scene_assignment_errors).each { |message| errors.add(:scenes, message) }
    end
end
