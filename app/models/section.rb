class Section < ApplicationRecord
  include Hierarchical
  include HasManyTags
  include HasSlug
  include InvalidatesMenuCounts

  invalidates_menu_counts_for :story

  belongs_to :story
  has_many_tags :section_tag

  validates :name, presence: true
  validate :section_tags_belong_to_story

  # Sections are scoped to their story instead of directly to the universe.
  private

  def section_tags_belong_to_story
    return if story.nil? || section_tags.all? { |section_tag| section_tag.story_id == story_id }

    errors.add(:section_tags, "must belong to the same story")
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
