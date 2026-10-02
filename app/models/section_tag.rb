class SectionTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug
  include HasPhoto
  include SoftDeletable
  include Searchable
  include HasDiscussion

  searchable kind: "tag", title: :name, body: :description, route: "section_tag", taxonomy: "Section", scope: :story
  soft_deletes :children

  belongs_to :story
  has_many_tagged :section, scope: :story_id

  validates :name, presence: true

  # Section tags are scoped to their story instead of to the universe.
  private

  def hierarchy_scope
    story
  end

  def hierarchy_scope_attribute
    :story_id
  end

  def hierarchy_scope_error_key
    "shared.errors.same_scope.story"
  end
end
