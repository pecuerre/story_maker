class Item < ApplicationRecord
  include Hierarchical
  include HasManyTypes

  belongs_to :story
  has_many_types :item_type
  has_many :ownerships, dependent: :destroy

  validates :name, presence: true
end
