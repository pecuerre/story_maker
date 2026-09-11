class ItemType < ApplicationRecord
  include Hierarchical
  include HasColor

  belongs_to :story
  has_many :items, dependent: :destroy

  validates :name, presence: true
end
