class CharacterType < ApplicationRecord
  belongs_to :story
  has_many :characters, dependent: :destroy
  include Hierarchical

  validates :name, presence: true
end
