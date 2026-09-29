class RelationTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug
  include HasPhoto
  include SoftDeletable
  include Searchable
  searchable kind: "tag", title: :name, body: :description, route: "relation_tag", taxonomy: "Relation"

  soft_deletes :children

  belongs_to :universe
  has_many_tagd :relation, scope: :universe_id

  validates :name, presence: true
  validates :inverse, presence: true, unless: :symmetric?
end
