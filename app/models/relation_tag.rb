class RelationTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug

  belongs_to :universe
  has_many_tagd :relation, scope: :universe_id

  validates :name, presence: true
  validates :inverse, presence: true, unless: :symmetric?
end
