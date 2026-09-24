class Character < ApplicationRecord
  include Hierarchical
  include HasManyTags
  include HasSlug
  include InvalidatesMenuCounts

  invalidates_menu_counts_for :universe

  belongs_to :universe
  has_many_tags :character_tag, scope: :universe_id
  has_many :relations_as_character1, class_name: "Relation", foreign_key: :character1_id, dependent: :destroy
  has_many :relations_as_character2, class_name: "Relation", foreign_key: :character2_id, dependent: :destroy
  has_many :ownerships, dependent: :destroy

  validates :name, presence: true
end
