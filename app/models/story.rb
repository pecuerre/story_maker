class Story < ApplicationRecord
  SECTION_MENU_COUNT_SCOPE = :story
  SCENE_MENU_COUNT_SCOPE = :story_scenes
  PLOT_MENU_COUNT_SCOPE = :story_plots

  include HasSlug
  include HasPhoto
  include SoftDeletable
  include InvalidatesUniverseSummary
  include Searchable
  include HasDiscussion

  searchable kind: "story", title: :name, body: :description, route: "story"
  soft_deletes :sections, :section_tags, :scene_tags, :plots, :scenes

  after_destroy_commit :expire_story_menu_counts
  # A rename changes this story's slug, and every document below it stores a path
  # carrying that slug. This story's own document is rewritten by the save itself,
  # so the repair is for the records underneath it.
  after_update_commit :queue_search_reindex, if: :saved_change_to_slug?
  belongs_to :universe
  has_many :sections, dependent: :destroy
  has_many :section_tags, dependent: :destroy
  has_many :scene_tags, dependent: :destroy
  has_many :plots, dependent: :destroy
  has_many :scenes, dependent: :destroy
  has_many :story_tropes, dependent: :destroy

  accepts_nested_attributes_for :story_tropes, allow_destroy: true,
    reject_if: ->(attributes) { attributes["id"].blank? && !ActiveModel::Type::Boolean.new.cast(attributes["selected"]) }

  before_validation :mark_unselected_story_tropes_for_destruction

  validates :name, presence: true, uniqueness: { scope: :universe_id }
  validates :slug, uniqueness: { scope: :universe_id, conditions: -> { where(deleted_at: nil) } }

  def build_trope_assignments
    assigned_slugs = story_tropes.map(&:trope_slug)
    TropeCatalog.entries.each do |entry|
      story_tropes.build(trope_slug: entry.slug, selected: false) unless assigned_slugs.include?(entry.slug)
    end
  end

  def menu_section_count
    MenuCountCache.fetch(MenuCountCache.key(SECTION_MENU_COUNT_SCOPE, id), connection: self.class.connection) do
      sections.count
    end
  end

  # Scenes are a second scalar metric on the same owner, so they use their own
  # cache entry instead of overwriting the section count.
  def menu_scene_count
    MenuCountCache.fetch(MenuCountCache.key(SCENE_MENU_COUNT_SCOPE, id), connection: self.class.connection) do
      scenes.count
    end
  end

  def menu_plot_count
    MenuCountCache.fetch(MenuCountCache.key(PLOT_MENU_COUNT_SCOPE, id), connection: self.class.connection) do
      plots.count
    end
  end

  private
    def mark_unselected_story_tropes_for_destruction
      story_tropes.each do |assignment|
        assignment.mark_for_destruction if assignment.persisted? && !assignment.selected
      end
    end

    def expire_story_menu_counts
      [ SECTION_MENU_COUNT_SCOPE, SCENE_MENU_COUNT_SCOPE, PLOT_MENU_COUNT_SCOPE ].each do |scope|
        MenuCountCache.expire(scope, id)
      end
    end

    def queue_search_reindex
      Search::ReindexStoryJob.perform_later(id)
    end
end
