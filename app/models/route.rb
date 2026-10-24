class Route < ApplicationRecord
  include HasSlug
  include HasPhoto
  include OptionalName
  include SoftDeletable
  include InvalidatesMenuCounts
  include InvalidatesUniverseSummary
  include Searchable
  include HasDiscussion

  searchable kind: "route", title: :display_string, body: :description, route: "route"
  invalidates_menu_counts_for :universe

  belongs_to :universe
  belongs_to :from_location, class_name: "Location"
  belongs_to :to_location, class_name: "Location"

  before_validation :generate_slug, on: :create, prepend: true
  validates :from_location, :to_location, presence: true
  validate :locations_belong_to_universe

  def display_string
    name.presence || "#{from_location&.name} → #{to_location&.name}"
  end

  private

  def generate_slug
    return if slug.present?

    if name.present?
      name_slug = slugify(name)
      return self.slug = name_slug if name_slug.present?
    end

    parts = [ from_location&.slug, to_location&.slug ].compact
    self.slug = parts.presence&.join("-") || SecureRandom.hex(4)
  end

  def locations_belong_to_universe
    { from_location: from_location, to_location: to_location }.each do |attribute, location|
      errors.add(attribute, I18n.t("routes.errors.must_belong_to_universe")) if location && universe && location.universe_id != universe_id
    end
  end
end
