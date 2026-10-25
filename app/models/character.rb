class Character < ApplicationRecord
  include Hierarchical
  include HasManyTags
  include HasSlug
  include HasPhoto
  include SoftDeletable
  include InvalidatesMenuCounts
  include InvalidatesUniverseSummary
  include Searchable
  include HasDiscussion

  searchable kind: "character", title: :name, body: :search_description, route: "character"
  invalidates_menu_counts_for :universe
  soft_deletes :children, :relations_as_character1, :relations_as_character2, :ownerships, :scene_characters,
    :character_knowledges
  before_destroy :clear_faction_memberships

  belongs_to :universe
  has_many_tags :character_tag, scope: :universe_id
  has_and_belongs_to_many :factions, ->(character) { where(universe_id: character.universe_id) },
    join_table: :characters_factions
  has_many :relations_as_character1, class_name: "Relation", foreign_key: :character1_id, dependent: :destroy
  has_many :relations_as_character2, class_name: "Relation", foreign_key: :character2_id, dependent: :destroy
  has_many :ownerships, dependent: :destroy
  # The speaker side of the Scene Element link. Deleting a Character removes its
  # speaker links and presence links; it never removes a Scene.
  has_and_belongs_to_many :scene_elements, join_table: :scene_element_speakers, foreign_key: :character_id
  # Turn rows remain when the Character is soft-deleted, just like the plain
  # speaker join above, so restoring the Character restores its attributed lines.
  # A hard destroy removes those rows rather than leaving a dangling speaker FK.
  has_many :scene_dialogue_turns_as_speaker, -> { with_deleted }, class_name: "SceneDialogueTurn",
    foreign_key: :speaker_id, inverse_of: :speaker, dependent: :destroy
  # `:destroy` rather than `:delete_all`, because a presence link is a record in
  # its own right: it carries a discussion, and `delete_all` skips callbacks, so
  # it would remove the link row and leave the thread behind pointing at nothing.
  has_many :scene_characters, dependent: :destroy
  has_many :character_knowledges, dependent: :destroy
  has_many :deleted_character_knowledges, -> { only_deleted }, class_name: "CharacterKnowledge",
    foreign_key: :character_id, dependent: :destroy
  has_many :source_knowledge_entries, -> { with_deleted }, class_name: "CharacterKnowledge", foreign_key: :source_character_id,
    dependent: :nullify

  validates :name, presence: true
  validate :factions_belong_to_same_universe

  def search_description
    [ at_a_glance, wants, needs, lies_to_self, contradictions, under_pressure_they, self[:never] ]
      .compact_blank.join(" ")
  end

  private

  def factions_belong_to_same_universe
    factions.each do |faction|
      next if faction.universe_id == universe_id

      errors.add(:factions, I18n.t("shared.errors.same_scope.universe"))
    end
  end

  def clear_faction_memberships
    factions.clear
  end
end
