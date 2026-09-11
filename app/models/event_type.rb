class EventType < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTypes

  belongs_to :story
  has_many_typed :event

  validates :name, presence: true
end
