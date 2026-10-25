class FactionRelationship < ApplicationRecord
  include HasSlug
  include HasPhoto
  include OptionalName
  include SoftDeletable
  include InvalidatesMenuCounts
  include InvalidatesUniverseSummary
  include Searchable
  include HasDiscussion
  include TemporalInterval

  searchable kind: "faction_relationship", title: :display_string, body: :description, route: "faction_relationship"
  invalidates_menu_counts_for :universe
  has_temporal_interval from: :from_date, to: :to_date

  belongs_to :universe
  belongs_to :from_faction, class_name: "Faction"
  belongs_to :to_faction, class_name: "Faction"

  before_validation :generate_slug, on: :create, prepend: true

  validates :from_faction, :to_faction, presence: true
  validate :factions_are_distinct
  validate :factions_belong_to_universe

  # Names are useful short labels; without one the directed endpoints are the
  # unambiguous name of the link in lists, details, and search.
  def display_string
    name.presence || "#{from_faction&.name} → #{to_faction&.name}"
  end

  private

  def generate_slug
    return if slug.present?

    if name.present?
      name_slug = slugify(name)
      return self.slug = name_slug if name_slug.present?
    end

    parts = [ from_faction&.slug, to_faction&.slug ].compact
    self.slug = parts.presence&.join("-") || SecureRandom.hex(4)
  end

  def factions_are_distinct
    return unless from_faction && to_faction
    return unless from_faction == to_faction || (from_faction_id.present? && from_faction_id == to_faction_id)

    errors.add(:to_faction, I18n.t("faction_relationships.errors.must_be_different"))
  end

  def factions_belong_to_universe
    { from_faction: from_faction, to_faction: to_faction }.each do |association, faction|
      next unless faction && universe

      unless faction.universe_id == universe_id
        errors.add(association, I18n.t("faction_relationships.errors.must_belong_to_universe"))
      end
    end
  end
end
