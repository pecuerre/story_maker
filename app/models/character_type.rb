class CharacterType < ApplicationRecord
  include Hierarchical

  belongs_to :story
  has_many :characters, dependent: :destroy

  validates :name, presence: true
end
