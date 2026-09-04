class Item < ApplicationRecord
  belongs_to :story
  belongs_to :item_type
  include Hierarchical

  validates :name, presence: true
end
