class OwnershipType < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTypes
  include HasSlug

  belongs_to :story
  has_many_typed :ownership

  validates :name, presence: true
end
