class Character < ApplicationRecord
  include Hierarchical

  belongs_to :story
  belongs_to :character_type
  has_many :relations_as_character1, class_name: "Relation", foreign_key: :character1_id, dependent: :destroy
  has_many :relations_as_character2, class_name: "Relation", foreign_key: :character2_id, dependent: :destroy
  has_many :ownerships, dependent: :destroy

  validates :name, presence: true
end
