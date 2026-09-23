class Story < ApplicationRecord
  include HasSlug

  after_destroy_commit :expire_menu_section_count
  belongs_to :universe
  has_many :sections, dependent: :destroy
  has_many :section_tags, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :universe_id }
  validates :slug, uniqueness: { scope: :universe_id }

  def menu_section_count
    MenuCountCache.fetch(MenuCountCache.key(:story, id), connection: self.class.connection) do
      sections.count
    end
  end

  private
    def expire_menu_section_count
      MenuCountCache.expire(:story, id)
    end
end
