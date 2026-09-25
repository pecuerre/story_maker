class Story < ApplicationRecord
  SECTION_MENU_COUNT_SCOPE = :story
  SCENE_MENU_COUNT_SCOPE = :story_scenes

  include HasSlug

  after_destroy_commit :expire_story_menu_counts
  belongs_to :universe
  has_many :sections, dependent: :destroy
  has_many :section_tags, dependent: :destroy
  has_many :scenes, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :universe_id }
  validates :slug, uniqueness: { scope: :universe_id }

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

  private
    def expire_story_menu_counts
      [ SECTION_MENU_COUNT_SCOPE, SCENE_MENU_COUNT_SCOPE ].each do |scope|
        MenuCountCache.expire(scope, id)
      end
    end
end
