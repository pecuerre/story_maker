class Section < ApplicationRecord
  include Hierarchical
  include HasManyTags
  include HasSlug
  include InvalidatesMenuCounts

  invalidates_menu_counts_for :story

  belongs_to :story
  has_many_tags :section_tag, scope: :story_id
  # Deleting a Section only clears Scene grouping. It never removes a Scene and
  # never changes a Scene's narrative position.
  has_many :scenes, dependent: :nullify

  validates :name, presence: true

  # Sections are scoped to their story instead of directly to the universe.
  private

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
