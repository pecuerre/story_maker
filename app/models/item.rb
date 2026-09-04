class Item < ApplicationRecord
  include Hierarchical

  belongs_to :story
  belongs_to :item_type

  validates :name, presence: true
end
