class Character < ApplicationRecord
  include Hierarchical
  include HasManyTags
  include HasSlug
  include SoftDeletable
  include InvalidatesMenuCounts
  include Searchable
  searchable kind: "character", title: :name, body: :description, route: "character"

  invalidates_menu_counts_for :universe

  soft_deletes :children, :relations_as_character1, :relations_as_character2, :ownerships, :scene_characters

  belongs_to :universe
  has_many_tags :character_tag, scope: :universe_id
  has_many :relations_as_character1, class_name: "Relation", foreign_key: :character1_id, dependent: :destroy
  has_many :relations_as_character2, class_name: "Relation", foreign_key: :character2_id, dependent: :destroy
  has_many :ownerships, dependent: :destroy
  # The speaker side of the Scene Element link. Deleting a Character removes its
  # speaker links and presence links; it never removes a Scene.
  has_and_belongs_to_many :scene_elements, join_table: :scene_element_speakers, foreign_key: :character_id
  has_many :scene_characters, dependent: :delete_all

  validates :name, presence: true
end
