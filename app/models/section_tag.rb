class SectionTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug

  belongs_to :story
  has_many_tagd :section, scope: :story_id

  validates :name, presence: true

  # Section tags are scoped to their story instead of to the universe.
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
