class Section < ApplicationRecord
  include Hierarchical
  include HasManyTags
  include HasSlug
  include HasPhoto
  include SoftDeletable
  include InvalidatesMenuCounts
  include Searchable

  searchable kind: "section", title: :name, body: :description, route: "section", scope: :story
  invalidates_menu_counts_for :story
  soft_deletes :children

  belongs_to :story
  has_many_tags :section_tag, scope: :story_id
  # Deleting a Section only clears Scene grouping. It never removes a Scene and
  # never changes a Scene's narrative position.
  has_many :scenes, dependent: :nullify

  validates :name, presence: true

  # Sections are scoped to their story instead of directly to the universe.
  private

  # A soft-deleted Section leaves its scenes in place but ungrouped, exactly
  # like a hard delete: the Section row is kept, the scenes' `section_id` is
  # cleared, and no Scene is removed or reordered.
  def soft_delete_dependencies
    scenes.update_all(section_id: nil)
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
