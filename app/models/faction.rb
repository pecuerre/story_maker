class Faction < ApplicationRecord
  include HasColor
  include HasManyTags
  include HasSlug
  include HasPhoto
  include SoftDeletable
  include InvalidatesMenuCounts
  include InvalidatesUniverseSummary
  include Searchable
  include HasDiscussion

  searchable kind: "faction", title: :name, body: :search_description, route: "faction"
  invalidates_menu_counts_for :universe
  soft_deletes :faction_relationships_as_from, :faction_relationships_as_to
  before_destroy :clear_character_memberships

  belongs_to :universe
  has_and_belongs_to_many :characters, ->(faction) { where(universe_id: faction.universe_id) },
    join_table: :characters_factions
  has_many_tags :faction_tag, scope: :universe_id
  has_many :faction_relationships_as_from, class_name: "FactionRelationship", foreign_key: :from_faction_id, dependent: :destroy
  has_many :faction_relationships_as_to, class_name: "FactionRelationship", foreign_key: :to_faction_id, dependent: :destroy

  validates :name, presence: true

  # The short summary is one line of plain text and is never rendered as
  # Markdown, but it may carry the same `[[kind:slug]]` references the
  # description does: the details page links them and a list row names them
  # without a link. The description is Markdown and is rendered by
  # `MarkdownDescription` when a page shows it. Both are part of the record's
  # search body, so a reader can find a Faction by what its profile says.
  def search_description
    [ summary, description ].compact_blank.join(" ")
  end

  private

  def clear_character_memberships
    characters.clear
  end
end
