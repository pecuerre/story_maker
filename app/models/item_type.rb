class ItemType < ApplicationRecord
  belongs_to :story
  has_many :items, dependent: :destroy
  include Hierarchical

  validates :name, presence: true
end
