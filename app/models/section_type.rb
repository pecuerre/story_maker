class SectionType < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTypes
  include HasSlug

  belongs_to :universe
  has_many_typed :section

  validates :name, presence: true
end
