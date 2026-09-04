class Character < ApplicationRecord
  belongs_to :story
  belongs_to :character_type
  include Hierarchical

  validates :name, presence: true
end
