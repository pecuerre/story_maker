class ItemType < ApplicationRecord
  include Hierarchical

  belongs_to :story
  has_many :items, dependent: :destroy

  validates :name, presence: true
end
