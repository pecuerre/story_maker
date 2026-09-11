class EventType < ApplicationRecord
  include Hierarchical
  include HasColor

  belongs_to :story
  has_many :events, dependent: :nullify

  validates :name, presence: true
end
