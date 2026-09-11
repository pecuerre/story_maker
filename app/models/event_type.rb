class EventType < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTypes
  include HasSlug

  belongs_to :story
  has_many_typed :event

  validates :name, presence: true
end
