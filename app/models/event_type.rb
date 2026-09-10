class EventType < ApplicationRecord
  include Hierarchical

  belongs_to :story
  has_many :events, dependent: :nullify

  validates :name, presence: true
  validates :color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a hex color like #d3d3d3" }
end
